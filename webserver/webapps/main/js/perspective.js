// PWA functionality for Ignition Perspective

// Check if running as PWA
function isPWA() {
    return window.matchMedia('(display-mode: standalone)').matches ||
           window.navigator.standalone === true;
}

// Log PWA status
console.log('PWA Status:', isPWA() ? 'Running as PWA' : 'Running in browser');

// Add PWA-specific behaviors
if (isPWA()) {
    // Prevent zoom on double tap
    let lastTouchEnd = 0;
    document.addEventListener('touchend', function (event) {
        const now = (new Date()).getTime();
        if (now - lastTouchEnd <= 300) {
            event.preventDefault();
        }
        lastTouchEnd = now;
    }, false);
    
    // Prevent pull-to-refresh on mobile
    document.body.style.overscrollBehavior = 'none';
}
