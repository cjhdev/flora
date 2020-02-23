window.onload = function fixTableHeader(event) {

  const thElements = document.getElementsByTagName('th');
  const tdElements = document.getElementsByTagName('td');
  
  for (let i = 0; i < thElements.length; i++) {
    const widerElement = thElements[i].offsetWidth > tdElements[i].offsetWidth ? thElements[i] : tdElements[i],
          width        = window.getComputedStyle(widerElement).width;

    thElements[i].style.width = tdElements[i].style.width = width;
  } 
   
};

function width(){
   return window.innerWidth 
       || document.documentElement.clientWidth 
       || document.body.clientWidth 
       || 0;
}
