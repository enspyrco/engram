// Loads the slides listed in source/deck.json and pages through them.
// Keys: ← → (or space, PageUp/PageDown), Home, End, N for notes, F for full screen.

(async () => {
  const canvas = document.getElementById('canvas');
  const count = document.getElementById('count');
  const notes = document.getElementById('notes');

  const deck = await (await fetch('source/deck.json')).json();
  document.title = deck.title;

  // One stylesheet link per distinct Google Fonts href in the deck's faces.
  const hrefs = new Set(Object.values(deck.faces).map((face) => face.href).filter(Boolean));
  for (const href of hrefs) {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    document.head.prepend(link);
  }

  const files = await Promise.all(
    deck.order.map(async (id) => (await fetch(`source/slides/${id}.html`)).text()),
  );
  canvas.innerHTML = files.join('\n');
  const slides = [...canvas.querySelectorAll(':scope > section')];

  let current = 0;

  const fit = () => {
    const scale = Math.min(innerWidth / 1920, innerHeight / 1080);
    canvas.style.transform = `translate(-50%, -50%) scale(${scale})`;
  };

  const show = (index) => {
    current = Math.max(0, Math.min(slides.length - 1, index));
    slides.forEach((slide, i) => slide.classList.toggle('active', i === current));
    count.textContent = `${current + 1} / ${slides.length}`;
    const aside = slides[current].querySelector('aside');
    notes.textContent = aside ? aside.textContent.trim() : '';
    history.replaceState(null, '', `#slide-${current + 1}`);
  };

  const fromHash = () => {
    const match = /^#slide-(\d+)$/.exec(location.hash);
    return match ? Number(match[1]) - 1 : 0;
  };

  const toggleNotes = () => { notes.hidden = !notes.hidden; };
  const toggleFullscreen = () => {
    if (document.fullscreenElement) document.exitFullscreen();
    else document.documentElement.requestFullscreen();
  };

  addEventListener('resize', fit);
  addEventListener('hashchange', () => show(fromHash()));
  addEventListener('keydown', (event) => {
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    const key = event.key;
    if (key === 'ArrowRight' || key === 'PageDown' || key === ' ') show(current + 1);
    else if (key === 'ArrowLeft' || key === 'PageUp') show(current - 1);
    else if (key === 'Home') show(0);
    else if (key === 'End') show(slides.length - 1);
    else if (key === 'n' || key === 'N') toggleNotes();
    else if (key === 'f' || key === 'F') toggleFullscreen();
    else return;
    event.preventDefault();
  });

  // Tap or click the right two-thirds to go forward, the left third to go back.
  document.getElementById('stage').addEventListener('click', (event) => {
    show(event.clientX > innerWidth / 3 ? current + 1 : current - 1);
  });
  document.getElementById('prev').addEventListener('click', () => show(current - 1));
  document.getElementById('next').addEventListener('click', () => show(current + 1));
  document.getElementById('toggle-notes').addEventListener('click', toggleNotes);
  document.getElementById('fullscreen').addEventListener('click', toggleFullscreen);

  fit();
  show(fromHash());
})();
