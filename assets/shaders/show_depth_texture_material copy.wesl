// BevyのPBRレンダリングパイプラインで定義されている頂点シェーダーの出力構造体 (VertexOutput) をインポートする。
// これにより、頂点シェーダーから渡されるUV座標やクリップ空間座標などの標準データをフラグメントシェーダーで利用できるようになる。
import bevy_pbr::render::forward_io::VertexOutput;

// マテリアルのバインドグループ (group 2) に属する、深度専用の2Dテクスチャバインドを定義。
// @group(constants::MATERIAL_BIND_GROUP): Bevyがカスタムマテリアル用に提供するバインドグループ番号（通常はグループ2）を指定。
// @binding(0): バインドグループ内のインデックス0番に割り当てられたテクスチャリソース。
// var depth_texture: texture_depth_2d;: 浮動小数点などの色ではなく、深度値（0.0〜1.0）が格納された2D深度テクスチャ型として変数を定義。
@group(constants::MATERIAL_BIND_GROUP) @binding(0) var depth_texture: texture_depth_2d;

// マテリアルのバインドグループ (group 2) に属する、深度比較用サンプラーを定義。
// @binding(1): バインドグループ内のインデックス1番に割り当てられたサンプラーリソース。
// var depth_sampler: sampler_comparison;: 深度テクスチャのサンプリングや比較処理を行うための比較サンプラー型として変数を定義。
@group(constants::MATERIAL_BIND_GROUP) @binding(1) var depth_sampler: sampler_comparison;

// この関数がフラグメント（ピクセル単位の描画処理）シェーダーのエントリポイントであることを宣言する。
// input: VertexOutput: 頂点シェーダーから補間されて渡されてきた入力データ（UV座標 `input.uv` などを含む）。
// -> @location(0): この関数が返す vec4 の色データを、レンダーターゲットのカラーアタッチメント0番に出力することを指定。
@fragment
fn fragment(input: VertexOutput) -> @location(0) vec4<f32> {
    // 【処理解説: テクセル座標への変換】
    // 1. `textureDimensions(depth_texture)`: バインドされた深度テクスチャの解像度（幅と高さの vec2<u32>）を動的に取得する組み込みAPI。
    // 2. `.xy`: ベクトルのX成分（幅）とY成分（高さ）を取り出し、`vec2<f32>` にキャストする。
    // 3. `input.uv * ...`: 0.0〜1.0の範囲であるUV座標にテクスチャのピクセルサイズを掛け合わせることで、何ピクセル目かという実座標を計算する。
    // 4. `vec2<i32>(...)`: 整数型のテクスチャロード関数へ渡すために、浮動小数点座標を `i32` 型の2次元整数ベクトルに変換する。
    let st = vec2<i32>(input.uv * vec2<f32>(textureDimensions(depth_texture).xy));

    // 【処理解説: 深度の読み込みとカラー化】
    // 1. `textureLoad(depth_texture, st, 0)`: サンプラー（補間処理）を介さず、指定した整数ピクセル座標(`st`)とミップレベル(`0`)の深度値（0.0〜1.0のf32）を直接フェッチ（ロード）するグラフィックスAPI。
    // 2. `vec3(...)`: 読み込んだスカラーの深度値をRGBの3成分すべてに複製し、グレースケール用の3次元ベクトルを作る。
    // 3. `vec4(..., 1.0)`: RGBにアルファ値（不透明度 `1.0`）を付与して、最終的な4次元カラーベクトル `vec4<f32>` を構築して返す。
    return vec4(vec3(textureLoad(depth_texture, st, 0)), 1.0);
}