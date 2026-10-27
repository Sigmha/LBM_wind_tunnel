shader_type canvas_item;

uniform int mode = 2;            // 0 = u_y, 1 = vitesse |u|, 2 = vorticité, 3 = rho, 4 = streamline
uniform float vmax = 0.03;       // échelle modes 0 et 1
uniform float wmax = 0.004;      // échelle vorticité
uniform sampler2D smoke_tex : filter_nearest;

vec3 diverging(float t) {        // t dans [-1,1] : bleu - blanc - rouge
	return (t > 0.0) ? mix(vec3(1.0), vec3(0.9, 0.1, 0.1), t)
	                 : mix(vec3(1.0), vec3(0.1, 0.2, 0.9), -t);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 d  = texture(TEXTURE, UV);               // (rho, ux, uy, solide)
	if (d.a > 0.5) {
		COLOR = vec4(0.2, 0.2, 0.2, 1.0);
	} else if (isnan(d.g) || isinf(d.g) || abs(d.r - 1.0) > 0.5) {
		COLOR = vec4(1.0, 0.0, 1.0, 1.0);         // divergence
	} else if (mode == 0) {
		COLOR = vec4(diverging(clamp(d.b / vmax, -1.0, 1.0)), 1.0);
	} else if (mode == 1) {
		float s = clamp(length(d.gb) / (1.5 * vmax), 0.0, 1.0);
		COLOR = vec4(vec3(1.0 - s, 1.0 - 0.5 * s, 1.0), 1.0);   // blanc -> bleu
	} else if (mode == 2) {
		float uyr = texture(TEXTURE, UV + vec2(px.x, 0.0)).b;
		float uyl = texture(TEXTURE, UV - vec2(px.x, 0.0)).b;
		float uxd = texture(TEXTURE, UV + vec2(0.0, px.y)).g;  
		float uxu = texture(TEXTURE, UV - vec2(0.0, px.y)).g;
		float w = 0.5 * (uyr - uyl) + 0.5 * (uxd - uxu);
		COLOR = vec4(diverging(clamp(w / wmax, -1.0, 1.0)), 1.0);
	} else if (mode == 3) {
		COLOR = vec4(diverging(clamp((d.r - 1.0) / 0.003, -1.0, 1.0)), 1.0);
	} else if (mode == 4) {
		float s = clamp(texture(smoke_tex, UV).r, 0.0, 1.0);
		COLOR = vec4(mix(vec3(0.04, 0.06, 0.10), vec3(1.0), s), 1.0);   // fond sombre, fumée blanche
	}
}