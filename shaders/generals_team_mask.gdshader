shader_type spatial;

uniform sampler2D body_texture : source_color;
uniform vec4 team_color : source_color = vec4(0.26, 0.77, 0.8, 1.0);
uniform float hit_flash = 0.0;

void fragment() {
	vec4 source = texture(body_texture, UV);
	// The supplied Ranger atlas paints its team panel red.
	float red_panel = smoothstep(0.06, 0.20, source.r - max(source.g, source.b));
	red_panel *= 1.0 - step(source.r * 0.25, max(source.g, source.b));
	ALBEDO = mix(source.rgb, team_color.rgb * source.r, red_panel);
	ROUGHNESS = 1.0;
	EMISSION = vec3(hit_flash);
}
