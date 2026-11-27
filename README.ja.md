# OPNsense で OCN バーチャルコネクト（MAP-E）を使うためのフォーク

[kawaii-not-kawaii/ds-lite-opnsense](https://github.com/kawaii-not-kawaii/ds-lite-opnsense) をフォークして、**OCN バーチャルコネクト（MAP-E）** で使えるように手を加えたものです。

- 修正は **`ocn-mape` ブランチ** にあります。`main` は本家のまま変更していません
- 本家へのプルリクエストは出していません
- 本家の英語の README（[README.md](README.md)）も、あわせて参照してください

> ⚠️ **実験的なものです。** MAP-E のモードは本家でも experimental 扱いです。使うときは、元のルーターにいつでも戻せるようにしておいてください。

---

## 本家からの変更点

| 変更 | 内容 |
|---|---|
| **CE アドレスの形式を選べるようにした** | `rfc`（RFC 7597、本家と同じ）と `draft03`（draft-ietf-softwire-map-03）から選べます。**OCN は `draft03` 形式です** |
| **OCN 用のプロファイルを追加** | 「OCN Virtual Connect」を選ぶと、BR `2001:380:a120::9`・PSID offset `6`・CE 形式 `draft03` が自動で入ります |
| **GUI に項目を追加** | 「MAP-E CE Address Format」（Advanced mode で表示）。空欄ならプロファイルの値を使います |
| **`mape_calc.sh` の引数を追加** | 6 番目の引数で CE 形式を指定できます |
| **テストを追加** | `os-dslite/tests/test_mape_ocn.sh` |

v6プラスのプロファイルは変更していません（`rfc` のまま）。

### なぜ CE アドレスの形式が重要なのか

MAP-E では、ルーターの IPv6 アドレス（CE アドレス）の後半に、IPv4 アドレスと PSID を埋め込みます。この埋め込み方には、正式規格（RFC 7597）と、それより前の草案（draft-03）の 2 種類があります。

```text
rfc     : 0000 | IPv4（32bit） | PSID（16bit）
draft03 :   00 | IPv4（32bit） | PSID（16bit） | 00
```

OCN バーチャルコネクトは draft03 形式を使っています。形式を間違えると、**トンネルは上がっているのに、OCN 側の中継地点（BR）がパケットを捨ててしまい、何も通りません**。

---

## 動作確認した環境

| 項目 | 内容 |
|---|---|
| 回線 | NTT 東日本 フレッツ光クロス相当（光コラボの 10 ギガプラン）、ひかり電話なし |
| プロバイダ | OCN（OCN バーチャルコネクト） |
| IPv6 | ONU 直結で DHCPv6-PD（/56） |
| OPNsense | 26.7 amd64 |
| NIC | Intel X550-T2 |

### 確認できたこと

- このフォークで計算した IPv4 アドレス・PSID・CE アドレス・ポート範囲（63 ブロック）が、同じ回線で動いていた Buffalo WSR-5400AX6 の表示と**完全に一致**
- OPNsense 26.7 の pf が `map-e-portset` に対応していること（`pfctl -n` で構文チェック）
- ONU 直結で、LAN 側の PC から IPv4（MAP-E 経由）と IPv6 の通信ができたこと

### まだ確認できていないこと・既知の問題

- **長時間の安定性**：まだ検証中です
- **設定画面の表示が「Tunnel Up (No Internet)」になる**：状態チェックは OPNsense 自身からの ping で行っています。ルーター自身が出す ICMP が、MAP-E のポート範囲に変換されていない可能性があります（調査中）
- **メニューに「DS-Lite」が出ない場合がある**：設定ページは `https://<OPNsense の LAN アドレス>/ui/dslite/general` で直接開けます

---

## OCN の MAP ルールについて

OCN バーチャルコネクトでは、本来ルーターが OCN のサーバーから「MAP ルール」（IPv6 と IPv4 の対応表）を取得します。ただ、取得には非公開のキーが必要です。そのため、このプラグインでは**ルールを手で入力**します。

- 自分の IPv6 プレフィックスに当てはまるルールの行は、公開されているルール表（例：[OCN バーチャルコネクトの MAP-E のパラメーター取得（note）](https://note.com/imototakashi/n/n4a9d91472639)）から探します
- 先頭が一致する行を選びます。たとえば `2400:4052:1xxx:...` なら `2400:4052:1000::/36` の行です
- **OCN がルールを変更したり、IPv6 プレフィックスが変わったりすると、通信できなくなります**。その場合は、元のルーターに戻して新しい値を確認してください

### 入力する前に計算結果を確認する（強く推奨）

今使っているルーター（Buffalo など）が表示している IPv4 アドレスや CE アドレスと比べて、一致するか確かめてから使ってください。

```sh
sh /usr/local/opnsense/scripts/OPNsense/dslite/mape_calc.sh \
  <委譲プレフィックス>/56 <ルールのIPv6プレフィックス> <ルールのIPv4プレフィックス> <EA長> <PSID offset> draft03
```

例（架空のプレフィックス）：

```sh
sh /usr/local/opnsense/scripts/OPNsense/dslite/mape_calc.sh \
  2400:4052:1234:5600::/56 2400:4052:1000::/36 153.134.0.0/18 20 6 draft03
```

---

## インストール（オフライン）

本家の README にあるワンライナーは、TLS 証明書の検証を無効にして本家の最新版をダウンロードするので、**使わないことをおすすめします**。中身を確認したこのフォークを、手元からコピーしてインストールします。

**1. 作業用 PC で取得する**

```bash
git clone -b ocn-mape https://github.com/kohei0018/ds-lite-opnsense.git
```

**2. OPNsense にコピーする**

```bash
scp -r ds-lite-opnsense/os-dslite root@<OPNsense の LAN アドレス>:/tmp/
```

**3. OPNsense のシェルでインストールする**

```sh
sh /tmp/os-dslite/install.sh
```

`source: /tmp/os-dslite/src (offline)` と表示されれば、オフラインでインストールされています。

**4. テストを実行する**

```sh
sh /tmp/os-dslite/tests/test_mape_ocn.sh
```

13 項目すべて `ok` になれば OK です。

インストールしただけでは何も動きません（Enable がオフのため）。

---

## 設定

### OPNsense 本体（Interfaces）

**WAN**

| 項目 | 設定 |
|---|---|
| IPv4 Configuration Type | None |
| IPv6 Configuration Type | DHCPv6 |
| Prefix delegation size | 56 |
| Send prefix hint | オン |

**LAN**

| 項目 | 設定 |
|---|---|
| IPv6 Configuration Type | Track Interface |
| Parent interface | WAN |
| Assign prefix ID | `1`（CE アドレスは prefix ID 0 の /64 に入るので、LAN とは重ならないようにする） |

### プラグイン（Interfaces → DS-Lite）

| 項目 | 設定 |
|---|---|
| Enable | オン |
| Mode | MAP-E (experimental) |
| WAN Interface | **WAN**（LAN になっていないか確認） |
| MAP-E Profile | OCN Virtual Connect |
| MAP-E Rule IPv6 Prefix | 自分のルールの値（例：`2400:4052:1000::/36`） |
| MAP-E Rule IPv4 Prefix | 自分のルールの値（例：`153.134.0.0/18`） |
| MAP-E EA-bits Length | 自分のルールの値（例：`20`） |
| MAP-E CE Address Format | `draft-ietf-softwire-map-03 (OCN)` を明示的に選ぶのがおすすめ |
| BR Address / PSID Offset | 空欄（プロファイルの値を使う） |

---

## 動作確認

**OPNsense のシェルで**

```sh
pfctl -a 'dslite/nat' -sn
pfctl -a 'dslite/fw' -sr
```

表示の見本（**これ以外のルールが出たら使用を止めてください**）：

```text
nat on gif0 inet all -> <あなたのIPv4> map-e-portset 6/6/<PSID>
match out on gif0 all scrub (max-mss 1420)
match in on gif0 all scrub (max-mss 1420)
```

**LAN 側の PC で**

```bash
curl -4 https://ifconfig.me ; echo
curl -6 https://ifconfig.me ; echo
```

IPv4 が `mape_calc.sh` で計算したアドレスになっていれば、MAP-E 経由で通信できています。PC に Wi-Fi など別の経路があると、そちらから出てしまうので注意してください（Linux なら `--interface <有線のIF名>` を付ける）。

---

## 元に戻す

1. ONU のケーブルを元のルーターに挿し直す
2. OPNsense：System → Configuration → Backups で、作業前のバックアップを復元する

---

## 注意

- **自分の IPv6 プレフィックスや IPv4 アドレスは公開しないでください。** IPv6 プレフィックスは家庭ごとに固有で、しばらく変わらないことが多いため、設定やスクリーンショットを共有するときは伏せてください
- 本家の更新を取り込むときは、差分を確認してから取り込んでください
- 本家のリポジトリにはライセンスファイルがありません（このフォークを作った時点）
- 動作の保証はありません。自己責任で使ってください

---

## ブランチ

| ブランチ | 内容 |
|---|---|
| `main` | 本家のコピー（変更なし） |
| `ocn-mape` | 本家 ＋ OCN 対応の修正 |

## 参考資料

- [RFC 7597 – Mapping of Address and Port with Encapsulation (MAP-E)](https://www.rfc-editor.org/rfc/rfc7597)
- [ヤマハ：OCN バーチャルコネクトの MAP-E](https://www.rtpro.yamaha.co.jp/RT/docs/ocn_map_e/index.html)
- [OCN バーチャルコネクトの MAP-E のパラメーター取得（note）](https://note.com/imototakashi/n/n4a9d91472639)
- [jp-yen/map-e_ocn（OCN MAP-E の検証環境）](https://github.com/jp-yen/map-e_ocn)
