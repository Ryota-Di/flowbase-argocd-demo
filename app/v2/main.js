'use strict';
(async function checkoutV2(){
  const config = await (await fetch('/config.json',{cache:'no-store'})).json();
  const root = document.getElementById('checkout');
  const button = document.getElementById('next');
  const result = document.getElementById('result');
  root.dataset.version = config.version;
  root.dataset.mode = config.mode;
  document.getElementById('version').textContent = config.version + ' / 新機能';
  document.getElementById('feature').textContent = 'NEW：ワンクリック購入';
  button.textContent = '1クリックで購入する'; button.disabled = false;
  button.addEventListener('click',()=>{
    result.textContent='注文デモ完了（1クリック）'; button.disabled=true;
  });
})().catch(()=>{document.getElementById('result').textContent='画面設定を読み込めませんでした';});
