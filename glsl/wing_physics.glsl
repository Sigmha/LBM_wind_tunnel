#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 4, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer BufIn  { float f_in[];  };
layout(set = 0, binding = 1, std430) restrict writeonly buffer BufOut { float f_out[]; };
layout(set = 0, binding = 2, std430) restrict readonly buffer BufSolid { int solid[]; };
layout(set = 0, binding = 3, rgba32f) uniform restrict writeonly image2D out_img;
layout(set = 0, binding = 4, std430) buffer BufForce { int force[4]; };   // Fx, Fy, uy_sonde, réservé
const float FSCALE = 100000.0;

layout(push_constant, std430) uniform Params {
	int nx;
	int ny;
	float tau;
	float uin;
	float taum;     // tau- (moments impairs)
	int probe_n;    // indice du nœud sonde (y*nx + x)
	int write_img;   // 1 = écrire l'image de sortie à ce pas
	float pad2;
} p;

const int   EX[9]  = int[9](0, 1, 0, -1, 0, 1, -1, -1, 1);
const int   EY[9]  = int[9](0, 0, 1, 0, -1, 1, 1, -1, -1);
const int   OPP[9] = int[9](0, 3, 4, 1, 2, 7, 8, 5, 6);
const int   MIR[9] = int[9](0, 1, 4, 3, 2, 8, 7, 6, 5);
const float W[9]   = float[9](4.0/9.0, 1.0/9.0, 1.0/9.0, 1.0/9.0, 1.0/9.0,
							  1.0/36.0, 1.0/36.0, 1.0/36.0, 1.0/36.0);

// g : équilibre en écart au repos, geq = feq - w. drho = rho - 1.
float geq(int i, float drho, float ux, float uy) {
	float eu = float(EX[i]) * ux + float(EY[i]) * uy;
	float u2 = ux * ux + uy * uy;
	return W[i] * (drho + (1.0 + drho) * (3.0 * eu + 4.5 * eu * eu - 1.5 * u2));
}

void main() {
	int x = int(gl_GlobalInvocationID.x);
	int y = int(gl_GlobalInvocationID.y);
	if (x >= p.nx || y >= p.ny) return;

	int N = p.nx * p.ny;
	int n = y * p.nx + x;
	ivec2 px = ivec2(x, p.ny - 1 - y);

	if (solid[n] == 1) {
		for (int i = 0; i < 9; i++) f_out[i * N + n] = 0.0;           // g : repos = 0
		if (p.write_img == 1) {
			imageStore(out_img, px, vec4(1.0, 0.0, 0.0, 1.0));   // (nœud solide)
		}
		return;
	}

	float fxs = 0.0, fys = 0.0;

	// 1. Streaming pull (identique, sur g)
	float fp[9];
	for (int i = 0; i < 9; i++) {
		int xs = x - EX[i];
		int ys = y - EY[i];
		xs = (xs >= p.nx) ? p.nx - 2 : max(xs, 0);
		if (ys < 0 || ys >= p.ny) {
			fp[i] = f_in[MIR[i] * N + y * p.nx + xs];
		} else if (solid[ys * p.nx + xs] == 1) {
			float fo = f_in[OPP[i] * N + n];
			fp[i] = fo;
			fxs -= 2.0 * float(EX[i]) * fo;
			fys -= 2.0 * float(EY[i]) * fo;
		} else {
			fp[i] = f_in[i * N + ys * p.nx + xs];
		}
	}

	if (fxs != 0.0 || fys != 0.0) {
		atomicAdd(force[0], int(floor(fxs * FSCALE + 0.5)));
		atomicAdd(force[1], int(floor(fys * FSCALE + 0.5)));
	}

	// 1b. Entrée Zou-He : seul changement, le "1.0 +" dans rho
	if (x == 0) {
		float rin = (1.0 + fp[0] + fp[2] + fp[4] + 2.0 * (fp[3] + fp[6] + fp[7])) / (1.0 - p.uin);
		fp[1] = fp[3] + (2.0 / 3.0) * rin * p.uin;
		fp[5] = fp[7] + 0.5 * (fp[4] - fp[2]) + (1.0 / 6.0) * rin * p.uin;
		fp[8] = fp[6] + 0.5 * (fp[2] - fp[4]) + (1.0 / 6.0) * rin * p.uin;
	}

	// 1c. Sortie : gradient nul sur les populations entrantes (3, 6, 7)
	if (x == p.nx - 1) {
		fp[3] = f_in[3 * N + y * p.nx + (p.nx - 2)];
		fp[6] = f_in[6 * N + y * p.nx + (p.nx - 2)];
		fp[7] = f_in[7 * N + y * p.nx + (p.nx - 2)];
	}

	// 2. Moments : rho = 1 + drho, j = somme e*g
	float drho = 0.0, jx = 0.0, jy = 0.0;
	for (int i = 0; i < 9; i++) {
		drho += fp[i];
		jx += float(EX[i]) * fp[i];
		jy += float(EY[i]) * fp[i];
	}
	float rho = 1.0 + drho;
	float ux = jx / rho;
	float uy = jy / rho;
	
	if (n == p.probe_n) force[2] = int(floor(uy * 1.0e7 + 0.5));   // un seul thread écrit : pas d'atomique

	// 3. Collision TRT + éponge
	float Ls = 0.1 * float(p.nx);
	float dOut = clamp((float(x) - (float(p.nx) - Ls)) / Ls, 0.0, 1.0);
	float dIn = clamp((Ls - float(x)) / Ls, 0.0, 1.0);
	float sigma = 0.05 * dOut * dOut;
	sigma = max(sigma, 0.05 * dIn * dIn);
	float wp = 1.0 / p.tau;      // omega+ : fixe nu
	float wm = 1.0 / p.taum;     // omega- : levier de stabilité

	float ge[9];
	for (int i = 0; i < 9; i++) ge[i] = geq(i, drho, ux, uy);

	for (int i = 0; i < 9; i++) {
		int j = OPP[i];
		float gp = 0.5 * (fp[i] + fp[j]);      // partie paire
		float gm = 0.5 * (fp[i] - fp[j]);      // partie impaire
		float ep = 0.5 * (ge[i] + ge[j]);
		float em = 0.5 * (ge[i] - ge[j]);
		float gt = geq(i, 0.0, p.uin, 0.0);
		f_out[i * N + n] = fp[i] - wp * (gp - ep) - wm * (gm - em) - sigma * (fp[i] - gt);
	}
	
	if (p.write_img == 1) {
		imageStore(out_img, px, vec4(rho, ux, uy, 0.0));      // (fin de main)
	}
}
