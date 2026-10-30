// =============================================================================
// 深度表示 & 等高線カスタマイズシェーダー (WESL)
// =============================================================================
import bevy_pbr::render::forward_io::VertexOutput;

// -----------------------------------------------------------------------------
// バインドグループの定義（Rust側の ShowDepthTextureMaterial と対応）
// -----------------------------------------------------------------------------

// @group は数値ではなく constants::MATERIAL_BIND_GROUP を使用します 
// binding(0) は texture_2d

// Rust側: #[texture(0)]
@group(constants::MATERIAL_BIND_GROUP) @binding(0)
var depth_texture: texture_depth_2d;

@group(constants::MATERIAL_BIND_GROUP) @binding(1)
var depth_sampler: sampler_comparison;

// 【追加】Rust側: #[uniform(2)] cutoff_depth: f32
// しきい値（0.0 〜 1.0）を受け取るUniformバッファ
@group(constants::MATERIAL_BIND_GROUP) @binding(2)
var<uniform> cutoff_depth: f32;

// -----------------------------------------------------------------------------
// フラグメントシェーダー
// -----------------------------------------------------------------------------
@fragment
fn fragment(input: VertexOutput) -> @location(0) vec4<f32> {
    // 1. テクセル座標（整数ピクセル位置）を計算して生の深度値をロード
    let st = vec2<i32>(input.uv * vec2<f32>(textureDimensions(depth_texture).xy));
    let depth = textureLoad(depth_texture, st, 0);

    // 2. 背景（何も描画されていない空間）のハンドリング
    // 深度が 0.0 以下（または無効値）の場合は暗い背景色を返して終了
    if (depth <= 0.0) {
        return vec4<f32>(0.05, 0.05, 0.08, 1.0);
    }

    // 3. 【機能1】手前と奥での色分け（深度クリッピング / デバッグ表示）
    var base_color: vec3<f32>;
    if (depth > cutoff_depth) {
        // 手前（カメラに近い側）：鮮やかなシアン・青系
        base_color = vec3<f32>(0.1, 0.7, 1.0);
    } else {
        // 奥（カメラから遠い側）：オレンジ・赤系
        base_color = vec3<f32>(1.0, 0.3, 0.1);
    }

    // 4. 【機能2】等高線（Contour Line）の計算
    // depth (0.0~1.0) を 20倍にし、fract() で小数部分(0.0~1.0の繰り返し周期)を取り出す
    let line_pattern = fract(depth * 20.0);
    
    // 周期の開始部分（0.1未満の領域）を「黒い線」に設定
    if (line_pattern < 0.1) {
        base_color = vec3<f32>(0.0, 0.0, 0.0); // 等高線ライン
    }

    return vec4<f32>(base_color, 1.0);
}