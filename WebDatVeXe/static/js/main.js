document.addEventListener('DOMContentLoaded', () => {
    const menuToggle = document.getElementById('menu');
    const navMenu = document.querySelector('.nav-menu');
    const menuIcon = document.querySelector('.menu-icon');

    // Logic for mobile responsiveness if needed
    if (menuToggle) {
        menuToggle.addEventListener('change', () => {
            if (menuToggle.checked) {
                // Style for mobile menu open
                console.log('Menu opened');
            } else {
                console.log('Menu closed');
            }
        });
    }

    // Smooth scroll for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth'
                });
            }
        });
    });
});
