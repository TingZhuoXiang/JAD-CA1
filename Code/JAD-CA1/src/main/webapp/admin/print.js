// "Print roster" button on admin/event.jsp. Kept in a file because the Content-Security-Policy
// blocks inline scripts. The print layout itself is the @media print block in site.css.
document.addEventListener('click', (event) => {
    if (event.target.closest('[data-print]')) {
        window.print();
    }
});
