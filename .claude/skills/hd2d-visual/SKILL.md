---
name: hd2d-visual
description: "옥토패스 트래블러 특유의 HD-2D 룩(미니어처 디오라마 느낌)을 Godot 4에서 구현하는 레시피. Camera3D 화각과 CameraAttributesPractical DOF, WorldEnvironment 블룸·톤매핑, Sprite3D 빌보드 4속성, 낮·밤 라이팅 프리셋을 다룬다. 카메라·조명·포스트프로세싱·스프라이트 렌더 설정을 만지기 전에 반드시 읽을 것. 'HD-2D', '옥토패스 느낌', '카메라 세팅', '블룸', '심도', '화면이 밋밋', '낮밤 조명', '룩 개선' 요청 시 사용."
---

# HD-2D 비주얼 레시피

HD-2D는 "3D 씬에 조명과 DOF를 잘 넣는 것"이 **아니다.** 그렇게 만들면 그냥 3D 게임이 된다.
실제로 이 프로젝트에서 그 실수를 했고, 사용자에게 "이건 3D잖아"라는 지적을 받았다.

이름 그대로 **2D(도트)가 주인공이고 3D는 그 무대**다. 아래 순서대로 중요하다.

| 우선순위 | 요소 | 없으면 |
|---------|------|-------|
| **1** | **낮은 렌더 해상도** (640×360 → 확대) | 픽셀이 잘게 갈려 도트로 안 보인다 |
| **2** | **모든 표면이 픽셀아트 텍스처** | 매끈한 단색 머티리얼 = 3D 게임 |
| **3** | **캐릭터·소품은 2D 스프라이트** | 3D 박스만 있으면 2.5D가 아니다 |
| 4 | 얕은 심도(DOF) | 디오라마 느낌이 약해짐 |
| 5 | 좁은 화각 + 부감 고정 | 원근이 살아나 일반 3인칭처럼 보임 |
| 6 | 블룸 | 도트가 딱딱하고 건조해 보임 |

**1~3번이 빠지면 4~6번을 아무리 잘 잡아도 3D처럼 보인다.** 조명부터 만지지 말고 여기부터 확인하라.

## 1. 낮은 렌더 해상도 — 도트풍의 결정타

`project.godot`에서 내부 해상도를 낮추고 창에 확대한다. 1280으로 그대로 렌더하면 끝이다.

```
[display]
window/size/viewport_width=640
window/size/viewport_height=360
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="viewport"
window/stretch/aspect="keep"
```

`stretch/mode="viewport"`가 핵심이다. 640×360으로 렌더한 화면을 2배로 확대하므로 3D 지오메트리까지
픽셀이 굵어진다. `mode="canvas_items"`는 UI만 스케일하고 3D는 풀 해상도로 렌더하니 쓰지 말 것.

## 2. 픽셀아트 텍스처 — 단색 머티리얼 금지

3D 지오메트리(지면·벽·건물)에도 반드시 저해상도 텍스처를 입힌다. 32×32면 충분하다.

```
[sub_resource type="StandardMaterial3D" id="Mat_ground"]
albedo_texture = ExtResource("2_grass")
texture_filter = 0
uv1_scale = Vector3(11, 11, 11)
roughness = 1.0
```

`texture_filter = 0`(NEAREST)이 없으면 확대할 때 뭉개져 도트가 사라진다.

플레이스홀더 텍스처는 이미 만들어 뒀다 — 없거나 종류를 늘리려면:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tools/gen_placeholder_textures.gd
```

`tools/gen_placeholder_textures.gd`는 팔레트에서 픽셀을 하나씩 찍어 도트 질감을 만든다.
단색으로 채우면 도트로 보이지 않으므로, 베이스 색 3~4개를 섞고 하이라이트를 흩뿌린다.

## 3. 무엇을 스프라이트로, 무엇을 3D로

| 대상 | 방식 | 이유 |
|------|------|------|
| 캐릭터·NPC·적 | **Sprite3D** | 살아 움직이는 느낌은 2D 애니메이션에서 나온다 |
| 나무·덤불·풀·소품 | **Sprite3D** | 실루엣이 도트여야 화면 전체가 통일된다 |
| 지면·벽·건물·계단 | 3D 메시 | 캐릭터가 올라서고 가려지는 공간이 필요하다 |

**pixel_size를 전 스프라이트에서 통일한다.** 이 프로젝트는 `0.067` — 16×24 캐릭터가 약 1.6m가 된다.
값이 제각각이면 도트 크기가 달라져 한 화면에 있으면 즉시 어색하다.
지면 텍스처의 `uv1_scale`도 이 밀도에 맞춘다 (1m당 약 15px).

## 반드시 알아야 할 것 — DOF의 위치

**DOF는 `Environment`가 아니라 `CameraAttributesPractical`에 있다.**

Godot 4.7에 `Environment.dof_blur_far_enabled`는 **존재하지 않는다** (이 프로젝트에서 실측 확인).
Godot 3.x 시절 자료나 오래된 튜토리얼을 따라가면 여기서 막힌다. 반드시 카메라에 붙인다.

```
[sub_resource type="CameraAttributesPractical" id="CamAttr_field"]
dof_blur_far_enabled = true
dof_blur_far_distance = 11.0
dof_blur_far_transition = 3.0
dof_blur_near_enabled = true
dof_blur_near_distance = 8.0
dof_blur_near_transition = 2.0
dof_blur_amount = 0.16

[node name="FieldCamera" type="Camera3D" parent="."]
attributes = SubResource("CamAttr_field")
```

위 값은 카메라가 (0, 11, 11)에 있을 때 기준이다(피사체까지 약 15.6).
**거리 값은 카메라~피사체 실제 거리에 맞춰야 한다.** `far_distance`가 그 거리보다 멀면
화면의 모든 것이 블러 범위 밖이라 **DOF가 전혀 걸리지 않는다** — 실제로 이 실수를 겪었다.
카메라를 옮기면 이 값도 반드시 함께 조정한다.

**저해상도 렌더에서는 블러를 약하게 잡는다.** 640×360에서는 같은 `dof_blur_amount`도 훨씬 강해 보인다.
0.07~0.10이 적당하고, 0.15를 넘으면 화면 절반이 뭉개져 무엇을 조작하는지 알 수 없다.
(풀 해상도 기준 수치를 그대로 쓰면 과하게 걸린다.)

**DOF가 걸렸는지 확인하는 법:** 스크린샷에서 먼 오브젝트의 **가장자리와 그림자 경계**를 본다.
전체가 균일하게 선명하면 안 걸린 것이다.

## 카메라 — 각도가 화면 인상을 지배한다

```
[node name="FieldCamera" type="Camera3D" parent="."]
fov = 30.0
rotation_degrees = Vector3(-22, 0, 0)
position = Vector3(0, 10, 18)
attributes = SubResource("CamAttr_field")
```

- **부감 -20~25°** — 원작 스크린샷을 재보면 대부분 이 범위다(실내는 -15°까지). 무대를 바라보는 각도다.
  **-45°는 전략 시뮬레이션 시점이라 전혀 다른 게임처럼 보인다** — 실제로 이 실수를 했고 지적받았다.
- **fov 25~35** — 좁을수록 원근이 눌려 미니어처감이 강해진다. 기본값 75는 그냥 3D로 보인다.
- 플레이어를 따라갈 때도 **각도는 고정**하고 위치만 옮긴다. 각도가 흔들리면 디오라마 느낌이 깨진다.
- 원근 투영(`projection=0`)을 쓴다. 직교는 원근감이 사라져 오히려 밋밋해진다.

### 낮은 각도의 대가: 배경을 바로 뒤에 세워야 한다

각도를 낮추면 **화면 상단이 수십 미터 밖을 본다.** 카메라 높이 10, -22°면 화면 상단이 80m 밖이다.
배경이 멀리 있으면 화면 상단 몇 %에 눌려 배경 구실을 못 하고, 그 위는 빈 하늘색 띠가 된다.

원작의 마을이 하나같이 **절벽·숲·건물에 둘러싸인 좁은 공간**인 것은 연출이자 기술적 필연이다.

| 요소 | 배치 기준 |
|------|----------|
| 마을 활동 영역 | z −6 ~ +5 (카메라 앞 13~25m) |
| 배경 옹벽/단 | 마을 바로 뒤 (z ≈ −8), 높이 3m 이상 |
| 배경 숲 | 옹벽 위 (z −9 ~ −19), 나무 높이 7~12m |
| 지평선 차단벽 | z ≈ −23, 높이 15m 이상 |

## 스케일 감각 — 나무는 생각보다 훨씬 크다

캐릭터 1.6m 옆에 3m 나무를 세우면 덤불로 보인다. 실제 나무는 캐릭터의 4~7배다.

| 대상 | 실제 높이 | pixel_size (48px 텍스처 기준) |
|------|----------|------------------------------|
| 캐릭터 (24px) | 1.6m | 0.067 |
| 중경 나무 | 5m | 0.105 |
| 배경 숲 나무 | 7~11m | 0.14 ~ 0.23 |
| 전경 프레이밍 나무 | 8~9m | 0.17 ~ 0.19 |

## 전경 프레이밍 — 원작 스크린샷의 공통점

원작 화면은 예외 없이 **하단·좌우에 큰 오브젝트가 흐릿하게 걸려 있다** (풀숲, 난간, 덤불, 나무).
이것이 깊이를 만들고 화면을 무대처럼 감싼다. 없으면 아래쪽이 빈 바닥으로 남아 허전하다.

배치할 때 주의할 점: **카메라에 가까울수록 화면에 잡히는 가로 범위가 급격히 좁아진다.**
깊이 14m 지점의 화면 가로 반폭은 약 6.8m뿐이다 — x를 ±9에 두면 화면 밖으로 나간다.
계산식은 `반폭 = 깊이 × tan(가로 반각)`, 16:9에 fov 30이면 가로 반각은 약 25.5°다.

전경 오브젝트는 `cast_shadow = 0`으로 둔다. 화면 밖 물체의 그림자가 중앙에 드리우면 정체를 알 수 없는 얼룩이 된다.

## 비네팅 — Godot에는 없으므로 직접 그린다

원작 화면은 가장자리가 어둡게 떨어져 시선이 중앙에 모인다. `Environment`에 비네팅 기능이 없어
`shaders/vignette.gdshader`를 전체 화면 `ColorRect`(CanvasLayer, layer=10)에 씌운다.

**강하게 걸지 말 것.** `strength 0.85`는 모서리가 검게 뭉개져 내용이 안 보인다.
0.4 근처에서 시작하고, `radius`는 1.0, `softness`는 0.7 이상으로 경계를 번지게 한다.

## 그림자로 입체감을 만든다

태양 각도가 정오에 가까우면(-55°) 그림자가 짧아 화면이 납작해진다.
**-35~45°로 낮춰 그림자를 길게 뽑으면** 같은 지오메트리도 훨씬 입체적으로 보인다.

## WorldEnvironment

```
[sub_resource type="Environment" id="Env_field"]
background_mode = 1
background_color = Color(0.05, 0.06, 0.1, 1)
ambient_light_source = 2
ambient_light_color = Color(0.4, 0.45, 0.6, 1)
ambient_light_energy = 0.6
tonemap_mode = 2
glow_enabled = true
glow_intensity = 0.8
glow_bloom = 0.15
glow_hdr_threshold = 0.9
adjustment_enabled = true
adjustment_saturation = 1.15
adjustment_contrast = 1.05
```

- **글로우/블룸은 `Environment`가 맞다** (DOF와 달리). `glow_hdr_threshold`를 낮출수록 더 많은 픽셀이 번진다.
  0.9 근처면 밝은 부분만 은은하게 번지고, 0.5 아래로 내리면 화면 전체가 뿌예진다.
- **채도를 살짝 올린다** (1.1~1.2). 옥토패스의 색감은 실사적이지 않고 과장돼 있다.
- 톤매핑은 필모닉(2) 또는 ACES(3). 기본 Linear(0)는 밝은 곳이 쉽게 날아간다.

## Sprite3D 5속성 — 세트로 다룬다

캐릭터·오브젝트 스프라이트에 반드시 함께 설정한다. 하나만 빠져도 눈에 띄게 이상해진다.

```
[node name="Sprite3D" type="Sprite3D" parent="."]
billboard = 2
texture_filter = 0
alpha_cut = 1
shaded = true
pixel_size = 0.067
```

| 속성 | 값 | 빠뜨리면 |
|------|-----|---------|
| `billboard` | **2** (Y축 고정) | 1(완전 빌보드)이면 카메라를 향해 기울어져 바닥에 눕는다 |
| `texture_filter` | **0** (NEAREST) | 기본값 3은 픽셀아트를 뿌옇게 뭉갠다 |
| `alpha_cut` | **1** (DISCARD) | 투명 영역이 깊이 정렬을 망가뜨리고 그림자에 검은 사각형이 생긴다 |
| `shaded` | **true** | **기본값이 false다.** 조명을 받지 않아 밤에 배경만 어두워지고 캐릭터만 밝게 뜬다 |
| `pixel_size` | 프로젝트 통일값 (현재 `0.067`) | 스프라이트마다 다르면 도트 크기가 달라 한 화면에서 즉시 어색하다 |

`billboard=2`가 실루엣을, `shaded=true`가 분위기를 만든다.
`shaded`는 기본값이 꺼짐이라 놓치기 쉽고, 낮/밤 전환을 넣기 전까지는 문제가 드러나지 않는다.

**예외:** 자체 발광해야 하는 것(등불의 불꽃 등)은 `shaded=false`로 두는 편이 나을 수 있다.
다만 그러면 낮에도 빛나 보이므로, 대개는 `shaded=true`로 두고 `OmniLight3D`를 따로 붙인다.

## 장식은 코드로 흩뿌린다

풀·꽃 같은 소품 수십 개를 `.tscn`에 손으로 쓰면 파일이 읽기 어려워지고, 손으로 정한 좌표는
규칙적으로 보여 오히려 부자연스럽다. `scripts/field/scatter_props.gd`가 시드 고정 랜덤으로 뿌린다.
길·물·건물 위를 피하는 제외 영역과 `pixel_size` 흔들기가 들어 있으니, 새 필드에도 재사용하라.

시드를 고정하는 이유: 매번 배치가 달라지면 비주얼 변화의 원인이 배치인지 세팅인지 구분할 수 없다.

## 깊이 안개 (fog)

원경을 공기에 묻어 깊이감을 만든다. `Environment`에 있다.

```
fog_enabled = true
fog_light_color = Color(0.68, 0.76, 0.86, 1)
fog_density = 0.010
fog_aerial_perspective = 0.35
fog_sky_affect = 0.0
```

**안개와 DOF를 동시에 강하게 걸지 말 것.** 둘 다 "멀수록 흐리게"라 겹치면 화면 전체가
뿌옇고 대비 없는 사진처럼 된다 — 실제로 이 실수를 겪었다. 한쪽을 올리면 다른 쪽을 내린다.
`fog_light_color`는 `background_color`와 비슷하게 맞춰야 원경이 하늘로 자연스럽게 사라진다.

## 등불과 밤 연출

옥토패스의 밤이 인상적인 이유는 어두워서가 아니라 **작은 광원이 따뜻하게 번지기 때문**이다.
어둠은 그 빛을 돋보이게 하는 배경일 뿐이다.

- 등불 스프라이트에 `OmniLight3D`를 자식으로 붙인다 (`light_color` 주황빛, `omni_range` 5~7)
- 낮에는 `light_energy = 0`, 밤에는 3.0 — 낮/밤 Tween에 함께 넣는다
- **밤에 `glow_intensity`를 올린다** (0.85 → 1.4). 블룸이 등불을 번지게 해 분위기를 만든다
- **`omni_range`를 좁게 잡는다** (5 안팎). 넓으면 화면이 고르게 밝아져 밤 느낌이 사라진다 —
  밝은 웅덩이와 그 사이의 어둠이 교차해야 한다
- **등불 스프라이트 자체는 `shaded = false`**로 두고 낮/밤 밝기를 `modulate`로 제어한다.
  `shaded = true`면 조명 계산에 눌려 불이 꺼진 것처럼 보인다.
  밤 틴트는 `Color(2.4, 1.95, 1.15)`처럼 1을 넘겨 HDR로 주면 블룸이 걸린다
- **밤에는 `DirectionalLight3D`의 그림자를 끈다.** 태양 각도가 낮으면 10m 건물의 그림자가
  20m 넘게 뻗어 광장이 통째로 검게 덮인다. 달빛 그림자가 그렇게 진할 이유도 없다

### 광원은 개수보다 배치가 문제다

가로등 10개를 늘려도 프레임은 3fps만 줄었다(Forward+ 클러스터드 라이팅). **광원 개수를 아끼지 말라.**
정작 화면을 살린 건 광원이 아니라 **창문 발광**이었다 — 건물에 불이 켜지는 순간 도시가 살아난다.

### 창문은 노드가 아니라 텍스처로

창문을 개별 노드로 만들면 건물 몇 채에 수십 개가 된다. 파사드 텍스처에 창문을 그려 넣고,
**같은 좌표계로 발광 마스크를 함께 생성**해 `emission_texture`로 지정하면 창문만 빛난다.

```
albedo_texture = facade.png
emission_enabled = true
emission_texture = facade_emission.png   # 유리 부분만 밝고 나머지는 검정
emission_energy_multiplier = 2.2
```

두 장을 따로 그리면 좌표가 어긋나 벽이 빛나거나 창문이 어두운 채 남는다 —
`gen_placeholder_textures.gd`의 `_make_facade()`처럼 한 함수에서 같은 루프로 그린다.

### 빛무리는 볼류메트릭 대신 스프라이트로

등불 주변 공기가 빛나는 효과는 `volumetric_fog_enabled`로도 되지만
**프레임이 주기적으로 크게 튄다** — 평균 85fps인 씬의 최저가 16fps까지 떨어졌다.

방사형 그라디언트 스프라이트(`light_glow.png`)를 광원 위치에 겹치는 쪽이 훨씬 싸고 안정적이다.
`billboard = 1`(완전 빌보드), `alpha_cut = 0`(블렌딩), `modulate`를 1 넘게 주면 블룸까지 걸린다.
크기는 작게 — 크면 등불 자체를 삼켜 흰 원판만 남는다.

### 젖은 바닥

`ssr_enabled = true`로 화면 공간 반사를 켜고 바닥 `roughness`를 0.3 근처로 낮춘다.
거칠면 반사가 뭉개져 보이지 않는다. 볼류메트릭과 달리 프레임이 안정적이다(평균은 20% 정도 내려간다).

### 알파 블렌딩은 조명을 제대로 못 받는다

바닥 문양처럼 불투명하게 깔리는 텍스처에 `transparency = 1`(알파 블렌드)을 쓰면
깊이를 기록하지 않아 **검은 판으로 렌더된다.** 알파 컷을 쓴다:

```
transparency = 2
alpha_scissor_threshold = 0.5
```

### 군중은 무리 지어 세운다

균일 난수로 뿌리면 사람들이 일정 간격으로 늘어서 격자처럼 보인다.
무리 중심을 `인원수 / 3.5`개쯤 잡고 그 주위에 세우면 광장다워진다 (`scatter_props.gd`의 `_spawn_crowd`).
`shaded = true`를 유지해야 등불 근처만 밝고 먼 사람은 실루엣으로 남는다.

## 낮 / 밤 라이팅

`DirectionalLight3D`의 각도·색·에너지와 Environment 앰비언트를 함께 Tween한다.
빛만 바꾸고 앰비언트를 그대로 두면 그림자 속이 낮처럼 밝아 어색하다.

| | 낮 | 밤 |
|---|-----|-----|
| `light_color` | `Color(1, 0.96, 0.88)` 따뜻한 백색 | `Color(0.55, 0.62, 0.95)` 푸른 달빛 |
| `light_energy` | 1.2 | 0.35 |
| `rotation_degrees.x` | -55 (높은 해) | -25 (낮게 깔린 달) |
| 앰비언트 색 | `Color(0.5, 0.55, 0.6)` | `Color(0.15, 0.18, 0.35)` |
| 앰비언트 에너지 | 0.6 | 0.3 |
| `glow_intensity` | 0.8 | 1.1 (밤에 등불이 더 번져야 분위기가 산다) |

전환은 1.5~2초 Tween. 즉시 바꾸면 화면이 튄다.

```gdscript
# 전환은 한 Tween에 묶어야 조명과 앰비언트가 따로 놀지 않는다
var tw := create_tween().set_parallel()
tw.tween_property(sun, "light_energy", target_energy, 1.5)
tw.tween_property(sun, "light_color", target_color, 1.5)
tw.tween_property(env, "ambient_light_energy", target_ambient, 1.5)
```

## 작업 방법

- **한 번에 하나씩 바꾼다.** DOF·블룸·톤매핑을 동시에 만지면 어느 것이 효과를 냈는지 알 수 없다.
- **반드시 화면을 확인한다.** 헤드리스는 dummy 렌더러라 비주얼이 전혀 검증되지 않는다.
  스크린샷을 찍으면 에이전트도 직접 볼 수 있다:
  ```bash
  bash .claude/skills/godot-run/scripts/godot.sh shot _screenshots/check.png   # PNG 저장 후 Read로 확인
  bash .claude/skills/godot-run/scripts/godot.sh run 15                        # 창을 띄워 사람이 확인
  ```
- **플레이스홀더 지오메트리에는 머티리얼 색을 반드시 지정한다.** CSG의 기본 알베도는 순백색이라
  조명을 받으면 화면이 하얗게 날아가 아무것도 판단할 수 없다. 실제로 이 문제를 겪었다.
- **수치에 근거를 남긴다.** "fov 30 — 25 아래는 답답함" 처럼 트레이드오프를 주석에 적으면
  나중에 조정할 때 다시 처음부터 탐색하지 않아도 된다.
- **성능:** DOF와 블룸은 둘 다 비싸다. 프레임이 떨어지면 품질을 끄기 전에 렌더 해상도 스케일을 먼저 낮춘다.

## 문제 진단

| 증상 | 원인 |
|------|------|
| **그냥 3D 같다 / 도트풍이 아니다** | 위 1~3번을 순서대로 확인. 대개 렌더 해상도가 안 낮거나 텍스처가 단색이다. DOF부터 의심하지 말 것 |
| 화면이 까맣다 | 카메라 위치/각도 → 조명 존재 → `background_mode` 순으로 확인 |
| 화면이 하얗게 날아감 | 머티리얼 알베도가 순백색(CSG 기본값)이다. 반드시 텍스처나 중간톤 색을 지정 |
| 캐릭터가 화면에 너무 크다 | 카메라가 가깝다. 거리를 늘리고 DOF 거리도 함께 조정 |
| DOF가 안 걸린다 | `Environment`에 넣었거나(거긴 없다), `far_distance`가 피사체보다 멀다 |
| 캐릭터가 바닥에 누움 | `billboard`가 1이다. 2로 |
| 스프라이트가 뿌옇다 | `texture_filter`가 기본값 3이다. 0으로 |
| 그림자에 검은 사각형 | `alpha_cut`이 0이다. 1로 |
| 밤인데 밝다 | 조명만 낮추고 `ambient_light_energy`를 안 낮췄다 |
| 화면 전체가 뿌옇다 | `glow_hdr_threshold`가 너무 낮다 |
