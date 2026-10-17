'use strict';
(async function checkoutV1(){
  const config = await (await fetch('/config.json',{cache:'no-store'})).json();
  const root = document.getElementById('checkout');
  const button = document.getElementById('next');
  const result = document.getElementById('result');
  root.dataset.version = config.version;
  root.dataset.mode = config.mode;
  document.getElementById('version').textContent = config.version + ' / 従来フロー';
  document.getElementById('feature').textContent = '配送先・支払方法・注文内容を順番に確認します。';
  const labels = ['1. 配送先を確認','2. 支払方法を確認','3. 注文内容を確認'];
  let step = 0;
  button.textContent = labels[0]; button.disabled = false;
  button.addEventListener('click',()=>{
    step += 1;
    if(step === labels.length){
      result.textContent = '注文デモ完了（3ステップ）'; button.disabled = true;
    }else{
      result.textContent = `ステップ ${step} 完了`; button.textContent = labels[step];
    }
  });
})().catch(()=>{document.getElementById('result').textContent='画面設定を読み込めませんでした';});
