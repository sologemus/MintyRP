/* MintyRP loading screen — GMod Loading URL API
   https://wiki.facepunch.com/gmod/Loading_URL
*/

(function () {
	var bar = document.getElementById("progress-bar");
	var statusEl = document.getElementById("status-text");
	var serverEl = document.getElementById("server-name");
	var mapEl = document.getElementById("map-name");
	var gamemodeEl = document.getElementById("gamemode-name");

	var progress = 0;

	function setProgress(pct) {
		progress = Math.max(0, Math.min(100, pct));
		if (bar) bar.style.width = progress + "%";
	}

	function setStatus(text) {
		if (statusEl) statusEl.textContent = text || "";
	}

	/* GMod calls these globals while the client downloads */

	window.GameDetails = function (servername, serverurl, mapname, maxplayers, steamid, gamemode) {
		if (serverEl && servername) serverEl.textContent = servername;
		if (mapEl && mapname) mapEl.textContent = mapname;
		if (gamemodeEl && gamemode) gamemodeEl.textContent = gamemode;
		setStatus("Joining " + (servername || "server") + "…");
	};

	window.SetFilesTotal = function (total) {
		window._filesTotal = total || 0;
		window._filesNeeded = total || 0;
	};

	window.SetFilesNeeded = function (needed) {
		window._filesNeeded = needed || 0;
		var total = window._filesTotal || 0;
		if (total > 0) {
			var done = total - needed;
			setProgress((done / total) * 100);
			setStatus("Downloading files… " + done + " / " + total);
		}
	};

	window.DownloadingFile = function (fileName) {
		if (!fileName) return;
		var shortName = String(fileName);
		if (shortName.length > 48) shortName = "…" + shortName.slice(-46);
		setStatus("Downloading " + shortName);
	};

	window.SetStatusChanged = function (status) {
		if (status) setStatus(status);

		var s = String(status || "").toLowerCase();
		if (s.indexOf("workshop") !== -1) setProgress(Math.max(progress, 15));
		else if (s.indexOf("sending client info") !== -1) setProgress(Math.max(progress, 85));
		else if (s.indexOf("client info") !== -1) setProgress(Math.max(progress, 90));
		else if (s.indexOf("starting lua") !== -1) setProgress(Math.max(progress, 95));
		else if (s.indexOf("lua") !== -1) setProgress(Math.max(progress, 92));
	};

	/* Preview when opened in a normal browser */
	if (!window.gmod) {
		setStatus("Preview mode — connect via Garry's Mod to see live progress");
		var fake = 0;
		setInterval(function () {
			fake = (fake + 1.5) % 100;
			setProgress(fake);
		}, 120);
	}
})();
