document.addEventListener('DOMContentLoaded', async () => {
  try {
    const res = await fetch('https://api.isbriantorp.in/v1/');
    const data = await res.json();

    const image = document.getElementById('torpin-image');
    const label = document.getElementById('torpin-label');

    if (data.isBrianTorpin) {
      image.src = '/torpin.png';
      label.textContent = 'yes / no';
    } else {
      image.src = '/not-torpin.png';
      label.textContent = 'no / yes';
    }
  } catch (err) {
    console.error('Error fetching torpin status:', err);
  }
});