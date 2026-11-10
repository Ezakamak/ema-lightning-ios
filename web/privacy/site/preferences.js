document.documentElement.classList.add('js');
const select=document.querySelector('#theme');
try{const saved=localStorage.getItem('ema-theme');if(['light','dark'].includes(saved)){document.documentElement.dataset.theme=saved;select.value=saved;}}catch{}
select?.addEventListener('change',()=>{const value=select.value;if(value==='system')delete document.documentElement.dataset.theme;else document.documentElement.dataset.theme=value;try{if(value==='system')localStorage.removeItem('ema-theme');else localStorage.setItem('ema-theme',value);}catch{}});
