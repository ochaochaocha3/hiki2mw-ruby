Hiki2MediaWiki Ruby 版
======================
[クリエイターズネットワーク](http://cre.jp/) の Hiki のページのソースを MediaWiki のページのソースへと変換するためのスクリプトです。[Hiki2MediaWiki（汎用版）](http://www.li-sa.jp/ocha3/hiki2mw/general/)の Ruby 版です。

動作環境
--------
Ruby 1.9.2 以降。

使用法
------
標準入力から Hiki ソースを読み取り、標準出力に MediaWiki ソースを出力します。

    ruby hiki2mw.rb foo-hiki.txt > foo-mw.txt
