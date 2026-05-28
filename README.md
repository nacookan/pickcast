# Pickcast

他のアプリのウィンドウを取り込んで、1つの画面にまとめて表示する macOS アプリです。ビデオ通話の画面共有時に複数ウィンドウをまとめて共有するための用途を想定しています。

A macOS app that captures windows from other apps and arranges them in a unified multi-pane layout. Designed for sharing multiple windows at once during video calls.

![Pickcast screenshot](docs/screen1.png)

---

## ダウンロード

最新バージョンは[リリースページ](../../releases/latest)からダウンロードできます。

---

## 機能

- 最大4ペイン（メイン・左・右・下）にそれぞれ別アプリのウィンドウをミラーリング
- 5つのタブで独立したレイアウトを切り替え
- ペイン間でのドラッグ＆ドロップによるウィンドウの入れ替え
- ペイン境界のドラッグによるサイズ調整

## 動作環境

| 項目 | バージョン |
|------|-----------|
| macOS | 13.0 Ventura 以降 |
| 言語 | Swift 5.9 |
| フレームワーク | SwiftUI, ScreenCaptureKit, AVFoundation |
