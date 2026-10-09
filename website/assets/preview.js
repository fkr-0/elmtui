// Turn authored screenshot/GIF slots into real media as soon as the files exist.
for (const stage of document.querySelectorAll('[data-preview]')) {
  const path = stage.dataset.preview;
  const image = new Image();
  image.onload = () => {
    stage.style.backgroundImage = 'url("' + path.replace(/"/g, '') + '")';
    stage.classList.add('has-image');
  };
  image.src = path;
}
