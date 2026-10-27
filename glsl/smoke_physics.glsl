#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly  buffer PhiIn  { float phi_in[];  };
layout(set = 0, binding = 1, std430) restrict writeonly buffer PhiOut { float phi_out[]; };
layout(set = 0, binding = 2, std430) restrict readonly  buffer Solid  { int solid[]; };
layout(set = 0, binding = 3, rgba32f) uniform restrict readonly  image2D vel_img;     // image du LBM
layout(set = 0, binding = 4, r32f)    uniform restrict writeonly image2D smoke_img;   // sortie affichable

layout(push_constant, std430) uniform Params {   // 32 octets
	int nx;
	int ny;
	int spacing;   // écart entre filets (mailles)
	int thick;     // épaisseur d'un filet (mailles)
	float dt;      // déplacement en pas LBM (= SUBSTEPS)
	float pad0;
	float pad1;
	float pad2;
} p;

float fetch(int x, int y) {
	x = clamp(x, 0, p.nx - 1);
	y = clamp(y, 0, p.ny - 1);
	return phi_in[y * p.nx + x];          // les nœuds solides contiennent 0
}

void main() {
	int x = int(gl_GlobalInvocationID.x);
	int y = int(gl_GlobalInvocationID.y);
	if (x >= p.nx || y >= p.ny) return;
	int n = y * p.nx + x;

	float phi = 0.0;
	if (solid[n] == 0) {
		if (x == 0) {
			// injection : filets à l'entrée
			phi = (y % p.spacing < p.thick) ? 1.0 : 0.0;
		} else {
			// semi-Lagrangien : on remonte la trajectoire de dt pas
			vec4 d = imageLoad(vel_img, ivec2(x, p.ny - 1 - y));   // image : y inversé
			float xs = clamp(float(x) - p.dt * d.g, 0.0, float(p.nx - 1));
			float ys = clamp(float(y) - p.dt * d.b, 0.0, float(p.ny - 1));
			int x0 = int(floor(xs));
			int y0 = int(floor(ys));
			float fx = xs - float(x0);
			float fy = ys - float(y0);
			phi = mix(mix(fetch(x0, y0),     fetch(x0 + 1, y0),     fx),
					  mix(fetch(x0, y0 + 1), fetch(x0 + 1, y0 + 1), fx), fy);
		}
	}
	phi_out[n] = phi;
	imageStore(smoke_img, ivec2(x, p.ny - 1 - y), vec4(phi, 0.0, 0.0, 0.0));
}
