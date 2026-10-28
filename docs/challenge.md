既存の **`render_depth_to_texture.rs`**（Rust側）と **`show_depth_texture_material.wesl`**（シェーダー側）に手を加えて、**「しきい値による手前と奥の色分け（深度クリッピング）」** と **「等高線（Contour Line）エフェクト」** を実装します。

それぞれのファイルで「**どの部分をどう変更・追加すればよいか**」をインラインコメント付きで解説します。

---

### 1. Rust側の変更（`render_depth_to_texture.rs`）

Rust側では、シェーダーに色切り替えの「しきい値（`cutoff_depth`）」を送信できるように、マテリアル構造体と初期化処理を拡張します。

#### ① `ShowDepthTextureMaterial` 構造体の修正
既存の構造体定義を探し、`#[uniform(1)]` を追加します。

```rust
// =============================================================================
// カスタムマテリアル構造体
// =============================================================================
#[derive(Asset, TypePath, AsBindGroup, Debug, Clone)]
struct ShowDepthTextureMaterial {
    // @binding(0): 深度テクスチャのハンドル
    #[texture(0, sample_type = "unfilterable_float")]
    depth_texture: Handle<Image>,

    // 【追加】@binding(1): 手前と奥を判定する深度のしきい値（0.0 ~ 1.0）
    // AsBindGroup により、自動的に GPU の binding(1) へ f32 値が転送されます
    #[uniform(1)]
    cutoff_depth: f32,
}
```

#### ② `setup` 関数内のマテリアル生成箇所の修正
`setup` 関数内で `ShowDepthTextureMaterial` をアセットに追加している場所を探し、`cutoff_depth` の初期値をセットします。

```rust
    // マテリアルのインスタンス化部分
    let material_handle = materials.add(ShowDepthTextureMaterial {
        depth_texture: depth_texture_handle,
        
        // 【追加】しきい値の設定（例: 0.95）
        // ※値（0.0〜1.0）を調整することで、色の切り替わる距離が変わります
        cutoff_depth: 0.95,
    });
```

---

### 2. シェーダー側の変更（`show_depth_texture_material.wesl`）

シェーダー側では、Rustから受け取った `cutoff_depth` を使ってピクセルごとの色を判定し、さらに `fract()` 関数を使って一定距離ごとに等高線（黒い描画線）を描き込みます。

`assets/shaders/show_depth_texture_material.wesl` の全内容を以下のように書き換えてみてください。

```wesl
// =============================================================================
// 深度表示 & 等高線カスタマイズシェーダー (WESL)
// =============================================================================
import bevy_pbr::render::forward_io::VertexOutput;

// -----------------------------------------------------------------------------
// バインドグループの定義（Rust側の ShowDepthTextureMaterial と対応）
// -----------------------------------------------------------------------------

// Rust側: #[texture(0)]
@group(2) @binding(0)
var depth_texture: texture_2d<f32>;

// 【追加】Rust側: #[uniform(1)] cutoff_depth: f32
// しきい値（0.0 〜 1.0）を受け取るUniformバッファ
@group(2) @binding(1)
var<uniform> cutoff_depth: f32;

// -----------------------------------------------------------------------------
// フラグメントシェーダー
// -----------------------------------------------------------------------------
@fragment
fn fragment(input: VertexOutput) -> @location(0) vec4<f32> {
    // 1. テクセル座標（整数ピクセル位置）を計算して生の深度値をロード
    let st = vec2<i32>(input.uv * vec2<f32>(textureDimensions(depth_texture).xy));
    let depth = textureLoad(depth_texture, st, 0).x;

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
```

---

### 3. 動かす際の試行錯誤（実験ポイント）

ご自身で入力を完了させて実行した後、以下のパラメータを書き換えてブラウザやウインドウの表示変化を観察してみてください。

1. **しきい値の変更**:
   `render_depth_to_texture.rs` の `cutoff_depth: 0.95` を `0.90` や `0.99` などに変更してみると、青色と赤色の境界線が前後に移動します。
2. **等高線の密度の変更**:
   `show_depth_texture_material.wesl` の `depth * 20.0` の `20.0` という数値を `50.0` に増やすと、より細かい等高線（しま模様）が現れます。

コードの入力と動作確認の過程で、もしエラーが出たり意図と違う色になった場合はいつでもエラーログをお知らせください！

🎨 動作確認ができたら、次は時間の経過（`time`）をシェーダーに送って「等高線が波のようにゆらゆら動く視覚エフェクト」への拡張に挑戦してみますか？