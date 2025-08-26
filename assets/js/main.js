document.addEventListener("DOMContentLoaded", function() {
    // Smooth scrolling for navigation links
    const navLinks = document.querySelectorAll("nav a");
    navLinks.forEach(link => {
        link.addEventListener("click", function(e) {
            if (this.getAttribute("href").startsWith("#")) {
                e.preventDefault();
                const targetId = this.getAttribute("href").substring(1);
                const targetElement = document.getElementById(targetId);
                if (targetElement) {
                    targetElement.scrollIntoView({
                        behavior: "smooth"
                    });
                }
            }
        });
    });

    // Button interactions
    const buttons = document.querySelectorAll(".cta-button, .primary-btn, .secondary-btn");
    buttons.forEach(button => {
        button.addEventListener("click", function(e) {
            if (this.textContent.includes("Download")) {
                e.preventDefault();
                console.log("Download initiated");
            } else if (this.textContent.includes("Get Started") || 
                      this.textContent.includes("View Portfolio")) {
                e.preventDefault();
                console.log("Action triggered:", this.textContent);
            }
        });
    });

    // Analytics tracking
    if (typeof gtag !== "undefined") {
        gtag("config", "GA_MEASUREMENT_ID", {
            page_title: document.title,
            page_location: window.location.href
        });
    }

    // Dynamic date updates
    const now = new Date();
    const timeElements = document.querySelectorAll("time");
    timeElements.forEach(el => {
        if (!el.getAttribute("datetime") && 
            !el.textContent.includes(":") && 
            !el.classList.contains("article-date")) {
            el.textContent = now.toLocaleDateString();
        }
    });

    // Article date formatting
    const articleDates = document.querySelectorAll(".article-date");
    articleDates.forEach(el => {
        const daysAgo = parseInt(el.getAttribute("data-days")) || 0;
        const date = new Date(now);
        date.setDate(date.getDate() - daysAgo);
        el.textContent = date.toLocaleDateString("en-US", {
            year: "numeric",
            month: "long", 
            day: "numeric"
        });
        el.setAttribute("datetime", date.toISOString().split("T")[0]);
    });
});

// Header scroll effect
window.addEventListener("scroll", function() {
    const header = document.querySelector("header");
    if (window.scrollY > 100) {
        header.style.background = "rgba(255,255,255,0.95)";
        header.style.backdropFilter = "blur(10px)";
    } else {
        header.style.background = "#fff";
        header.style.backdropFilter = "none";
    }
});