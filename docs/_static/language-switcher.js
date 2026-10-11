/* Language and version dropdowns. The widget cluster is rendered in the
   Furo announcement block (docs/_templates/page.html) so its link URLs
   can be computed per page; this script pins it to the bottom-right
   corner of the viewport, removes the now-empty announcement bar, and
   handles the open/close interactions. Menu items are regular links, so
   the browser does the navigation. */
(function () {
  "use strict";

  var widgets = document.querySelectorAll(".docs-switcher");

  function setOpen(widget, open) {
    widget.querySelector(".docs-switcher-menu").hidden = !open;
    widget.querySelector(".docs-switcher-toggle").setAttribute("aria-expanded", String(open));
  }

  widgets.forEach(function (widget) {
    widget.querySelector(".docs-switcher-toggle").addEventListener("click", function (event) {
      event.stopPropagation();
      var open = widget.querySelector(".docs-switcher-menu").hidden;
      widgets.forEach(function (other) {
        if (other !== widget) {
          setOpen(other, false);
        }
      });
      setOpen(widget, open);
    });
  });

  document.addEventListener("click", function (event) {
    widgets.forEach(function (widget) {
      if (!widget.contains(event.target)) {
        setOpen(widget, false);
      }
    });
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") {
      widgets.forEach(function (widget) {
        setOpen(widget, false);
      });
    }
  });

  var cluster = document.querySelector(".docs-switchers");
  if (cluster) {
    document.body.appendChild(cluster);
    var announcement = document.querySelector(".announcement");
    if (announcement) {
      announcement.remove();
    }
  }
})();
