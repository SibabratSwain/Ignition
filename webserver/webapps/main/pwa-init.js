// PWA Initialization Script for Ignition Perspective
// This script handles service worker registration and PWA installation

class PWAManager {
    constructor() {
        this.deferredPrompt = null;
        this.installButton = null;
        this.init();
    }

    init() {
        this.registerServiceWorker();
        this.setupInstallPrompt();
        this.setupBeforeInstallPrompt();
        this.checkForUpdates();
        this.sendNotification()
    }

    // Register the service worker
    async registerServiceWorker() {
        if ('serviceWorker' in navigator) {
            try {
                console.log('PWA: Registering service worker...');
                
                const registration = await navigator.serviceWorker.register('sw.js', {
                    scope: '/'
                });

                console.log('PWA: Service worker registered successfully:', registration);

                // Handle service worker updates
                registration.addEventListener('updatefound', () => {
                    const newWorker = registration.installing;
                    console.log('PWA: Service worker update found');

                    newWorker.addEventListener('statechange', () => {
                        if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                            this.showUpdateNotification();
                        }
                    });
                });

                // Handle service worker messages
                navigator.serviceWorker.addEventListener('message', (event) => {
                    if (event.data && event.data.type === 'background-sync') {
                        console.log('PWA: Background sync completed');
                        this.handleBackgroundSync();
                    }
                });

            } catch (error) {
                console.error('PWA: Service worker registration failed:', error);
            }
        } else {
            console.warn('PWA: Service workers not supported');
        }
    }

    // Setup install prompt
    setupInstallPrompt() {
        // Create install button if it doesn't exist
        if (!document.getElementById('pwa-install-button')) {
            this.createInstallButton();
        }
    }

    // Handle beforeinstallprompt event
    setupBeforeInstallPrompt() {
        window.addEventListener('beforeinstallprompt', (e) => {
            console.log('PWA: Install prompt triggered');
            
            // Prevent the mini-infobar from appearing on mobile
            e.preventDefault();
            
            // Stash the event so it can be triggered later
            this.deferredPrompt = e;
            
            // Show install button
            this.showInstallButton();
        });

        // Handle successful installation
        window.addEventListener('appinstalled', (evt) => {
            console.log('PWA: App installed successfully');
            this.hideInstallButton();
            this.deferredPrompt = null;
            
            // Show success message
            this.showInstallationSuccess();
        });
    }

    // Create install button
    createInstallButton() {
        const button = document.createElement('button');
        button.id = 'pwa-install-button';
        button.className = 'pwa-install-button';
        button.innerHTML = `
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                <path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/>
            </svg>
            Install App
        `;
        
        button.addEventListener('click', () => {
            this.installApp();
        });

        // Add styles
        const style = document.createElement('style');
        style.textContent = `
            .pwa-install-button {
                position: fixed;
                bottom: 20px;
                right: 20px;
                background: #1976d2;
                color: white;
                border: none;
                border-radius: 50px;
                padding: 12px 20px;
                font-size: 14px;
                font-weight: 500;
                cursor: pointer;
                box-shadow: 0 4px 12px rgba(25, 118, 210, 0.3);
                display: flex;
                align-items: center;
                gap: 8px;
                z-index: 1000;
                transition: all 0.3s ease;
                opacity: 0;
                transform: translateY(20px);
            }
            
            .pwa-install-button:hover {
                background: #1565c0;
                transform: translateY(18px);
                box-shadow: 0 6px 16px rgba(25, 118, 210, 0.4);
            }
            
            .pwa-install-button.show {
                opacity: 1;
                transform: translateY(0);
            }
            
            .pwa-install-button svg {
                width: 16px;
                height: 16px;
            }
            
            .pwa-notification {
                position: fixed;
                top: 20px;
                right: 20px;
                background: white;
                border: 1px solid #e0e0e0;
                border-radius: 8px;
                padding: 16px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
                z-index: 1001;
                max-width: 300px;
                transform: translateX(100%);
                transition: transform 0.3s ease;
            }
            
            .pwa-notification.show {
                transform: translateX(0);
            }
            
            .pwa-notification h4 {
                margin: 0 0 8px 0;
                color: #1976d2;
                font-size: 16px;
            }
            
            .pwa-notification p {
                margin: 0 0 12px 0;
                color: #666;
                font-size: 14px;
            }
            
            .pwa-notification button {
                background: #1976d2;
                color: white;
                border: none;
                border-radius: 4px;
                padding: 8px 16px;
                font-size: 12px;
                cursor: pointer;
                margin-right: 8px;
            }
            
            .pwa-notification button.secondary {
                background: #f5f5f5;
                color: #666;
            }
        `;
        
        document.head.appendChild(style);
        document.body.appendChild(button);
        
        this.installButton = button;
    }

    // Show install button
    showInstallButton() {
        if (this.installButton) {
            this.installButton.classList.add('show');
        }
    }

    // Hide install button
    hideInstallButton() {
        if (this.installButton) {
            this.installButton.classList.remove('show');
        }
    }

    // Install the app
    async installApp() {
        if (!this.deferredPrompt) {
            console.log('PWA: No install prompt available');
            return;
        }

        try {
            // Show the install prompt
            this.deferredPrompt.prompt();
            
            // Wait for the user to respond to the prompt
            const { outcome } = await this.deferredPrompt.userChoice;
            
            console.log('PWA: User choice:', outcome);
            
            if (outcome === 'accepted') {
                console.log('PWA: User accepted the install prompt');
            } else {
                console.log('PWA: User dismissed the install prompt');
            }
            
            // Clear the deferredPrompt
            this.deferredPrompt = null;
            
            // Hide the install button
            this.hideInstallButton();
            
        } catch (error) {
            console.error('PWA: Error during installation:', error);
        }
    }

    // Show update notification
    showUpdateNotification() {
        const notification = document.createElement('div');
        notification.className = 'pwa-notification';
        notification.innerHTML = `
            <h4>Update Available</h4>
            <p>A new version of the app is available. Refresh to update.</p>
            <button onclick="this.parentElement.remove()">Refresh</button>
            <button class="secondary" onclick="this.parentElement.remove()">Later</button>
        `;
        
        document.body.appendChild(notification);
        
        // Show notification
        setTimeout(() => {
            notification.classList.add('show');
        }, 100);
        
        // Auto-hide after 10 seconds
        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => {
                if (notification.parentElement) {
                    notification.parentElement.removeChild(notification);
                }
            }, 300);
        }, 10000);
    }

    // Show installation success
    showInstallationSuccess() {
        const notification = document.createElement('div');
        notification.className = 'pwa-notification';
        notification.innerHTML = `
            <h4>Installation Complete</h4>
            <p>The app has been successfully installed on your device!</p>
            <button onclick="this.parentElement.remove()">OK</button>
        `;
        
        document.body.appendChild(notification);
        
        // Show notification
        setTimeout(() => {
            notification.classList.add('show');
        }, 100);
        
        // Auto-hide after 5 seconds
        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => {
                if (notification.parentElement) {
                    notification.parentElement.removeChild(notification);
                }
            }, 300);
        }, 5000);
    }

    // Handle background sync
    handleBackgroundSync() {
        // Refresh data or perform background tasks
        console.log('PWA: Handling background sync...');
        
        // You can add custom background sync logic here
        // For example, refresh cached data, sync offline changes, etc.
    }

    // Check for updates
    checkForUpdates() {
        if ('serviceWorker' in navigator) {
            navigator.serviceWorker.getRegistrations().then(registrations => {
                registrations.forEach(registration => {
                    registration.update();
                });
            });
        }
    }

    // Request notification permission
    async requestNotificationPermission() {
        if ('Notification' in window) {
            const permission = await Notification.requestPermission();
            console.log('PWA: Notification permission:', permission);
            return permission;
        }
        return 'denied';
    }

    // Send notification
    sendNotification(title, options = {}) {
        if ('Notification' in window && Notification.permission === 'granted') {
            const notification = new Notification(title, {
                icon: '/web/icons/icon-192x192.png',
                badge: '/web/icons/icon-72x72.png',
                ...options
            });

            notification.addEventListener('click', () => {
                window.focus();
                notification.close();
            });

            return notification;
        }
    }
}

// Initialize PWA when DOM is loaded
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.pwaManager = new PWAManager();
    });
} else {
    window.pwaManager = new PWAManager();
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = PWAManager;
} 