// Search, font switch and link previews. Pages work without this script.
(function () {
  "use strict";

  var root = document.body.getAttribute("data-root") || "";
  var tools = document.querySelector(".tools");

  function storage(action, key, value) {
    try {
      if (action === "get") return window.localStorage.getItem(key);
      window.localStorage.setItem(key, value);
    } catch (e) {
      return null;
    }
    return null;
  }

  // Font switch: readers can choose the face they read best.
  var fonts = [
    ["", "Atkinson Hyperlegible"],
    ["plex-serif", "IBM Plex Serif"],
    ["plex-sans", "IBM Plex Sans"]
  ];
  function setFont(value) {
    if (value) document.documentElement.setAttribute("data-font", value);
    else document.documentElement.removeAttribute("data-font");
  }
  setFont(storage("get", "sl-font") || "");

  if (tools) {
    var fontBox = document.createElement("div");
    fontBox.className = "font-switch";
    var label = document.createElement("label");
    label.htmlFor = "sl-font";
    label.textContent = "Font";
    var select = document.createElement("select");
    select.id = "sl-font";
    fonts.forEach(function (f) {
      var o = document.createElement("option");
      o.value = f[0];
      o.textContent = f[1];
      select.appendChild(o);
    });
    select.value = storage("get", "sl-font") || "";
    select.addEventListener("change", function () {
      setFont(select.value);
      storage("set", "sl-font", select.value);
    });
    fontBox.appendChild(label);
    fontBox.appendChild(select);

    // Search over names, about texts and the method text.
    var search = document.createElement("div");
    search.className = "search";
    search.setAttribute("role", "search");
    var searchLabel = document.createElement("label");
    searchLabel.htmlFor = "sl-search";
    searchLabel.className = "visually-hidden";
    searchLabel.textContent = "Search the method";
    var input = document.createElement("input");
    input.type = "search";
    input.id = "sl-search";
    input.placeholder = "Search";
    input.autocomplete = "off";
    var results = document.createElement("ul");
    results.className = "search-results";
    results.setAttribute("aria-live", "polite");
    search.appendChild(searchLabel);
    search.appendChild(input);
    search.appendChild(results);

    tools.appendChild(search);
    tools.appendChild(fontBox);

    var index = window.SL_SEARCH || [];
    input.addEventListener("input", function () {
      var terms = input.value.toLowerCase().split(/\s+/).filter(Boolean);
      results.innerHTML = "";
      if (!terms.length) return;
      var hits = [];
      index.forEach(function (e) {
        var title = e.t.toLowerCase();
        var body = (e.a + " " + e.x).toLowerCase();
        var score = 0;
        for (var i = 0; i < terms.length; i++) {
          if (title.indexOf(terms[i]) >= 0) score += 10;
          else if (body.indexOf(terms[i]) >= 0) score += 1;
          else return;
        }
        hits.push([score, e]);
      });
      hits.sort(function (a, b) { return b[0] - a[0]; });
      hits.slice(0, 12).forEach(function (h) {
        var li = document.createElement("li");
        var a = document.createElement("a");
        a.href = root + h[1].u;
        a.textContent = h[1].t;
        var small = document.createElement("small");
        small.textContent = h[1].k + (h[1].a ? " · " + h[1].a.slice(0, 120) : "");
        li.appendChild(a);
        li.appendChild(small);
        results.appendChild(li);
      });
      if (!hits.length) {
        var none = document.createElement("li");
        none.textContent = "No matches.";
        results.appendChild(none);
      }
    });
    input.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape") { input.value = ""; results.innerHTML = ""; }
    });
  }

  // Link previews: the target's summary on hover or focus.
  var box = null;
  function hide() { if (box) { box.remove(); box = null; } }
  function show(ev) {
    var a = ev.currentTarget;
    var text = a.getAttribute("data-preview");
    if (!text) return;
    hide();
    box = document.createElement("div");
    box.className = "preview";
    box.setAttribute("role", "tooltip");
    box.textContent = text;
    document.body.appendChild(box);
    var r = a.getBoundingClientRect();
    box.style.left = Math.max(8, Math.min(r.left + window.scrollX, window.scrollX + document.documentElement.clientWidth - box.offsetWidth - 8)) + "px";
    box.style.top = (r.bottom + window.scrollY + 6) + "px";
  }
  document.querySelectorAll("a[data-preview]").forEach(function (a) {
    a.addEventListener("mouseenter", show);
    a.addEventListener("focus", show);
    a.addEventListener("mouseleave", hide);
    a.addEventListener("blur", hide);
  });
  document.addEventListener("keydown", function (ev) { if (ev.key === "Escape") hide(); });
})();
