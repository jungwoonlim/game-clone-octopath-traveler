shader_type canvas_item;

// 화면 가장자리를 어둡게 깔아 시선을 중앙으로 모은다.
// 옥토패스의 화면이 "무대 조명을 받는 디오라마"처럼 보이는 큰 이유가 이것이다.
// Godot 4의 Environment에는 비네팅이 없어서 전체 화면 ColorRect에 직접 그린다.

uniform float strength : hint_range(0.0, 1.5) = 0.85;
// 값이 작을수록 어두운 영역이 안쪽까지 파고든다
uniform float radius : hint_range(0.2, 1.5) = 0.78;
// 경계가 뚜렷하면 원형 테두리가 눈에 보이므로 넉넉히 번지게 한다
uniform float softness : hint_range(0.05, 1.0) = 0.55;
uniform vec4 tint : source_color = vec4(0.02, 0.02, 0.06, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	// 16:9 화면에서 가로를 보정하지 않으면 비네팅이 세로로 찌그러진다
	uv.x *= 1.42;

	float d = length(uv);
	float v = smoothstep(radius * (1.0 - softness), radius, d) * strength;

	COLOR = vec4(tint.rgb, v);
}
