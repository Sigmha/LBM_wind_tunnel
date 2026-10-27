#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict writeonly buffer BufSolid { int solid[]; };

layout(push_constant, std430) uniform Params {   // 32 octets
	int nx;
	int ny;
	float ca;     // cos(alpha)
	float sa;     // sin(alpha)
	float xp;     // pivot
	float yp;
	float c;      // corde
	float trel;   // épaisseur relative
} p;

void main() {
	int x = int(gl_GlobalInvocationID.x);
	int y = int(gl_GlobalInvocationID.y);
	if (x >= p.nx || y >= p.ny) return;

	float dx = float(x) - p.xp;
	float dy = float(y) - p.yp;
	float xi  = 0.25 * p.c + dx * p.ca - dy * p.sa;   // le long de la corde
	float eta = dx * p.sa + dy * p.ca;                // normale à la corde

	int s = 0;
	if (xi >= 0.0 && xi <= p.c) {
		float xh = xi / p.c;
		float yt = 5.0 * p.trel * p.c * (0.2969 * sqrt(xh) - 0.1260 * xh
				 - 0.3516 * xh * xh + 0.2843 * xh * xh * xh - 0.1015 * xh * xh * xh * xh);
		if (abs(eta) <= max(yt, 1.0)) s = 1;
	}
	solid[y * p.nx + x] = s;
}
