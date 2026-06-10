(() => {
    'use strict';

    let RES = 'vnr_zonebuilder';
    let format = 'oxlib';

    const $ = (id) => document.getElementById(id);
    const hud = $('hud');
    const menu = $('menu');

    const TYPE_LABEL = { poly: 'polygon', circle: 'circle', box: 'box' };

    function post(name, data) {
        return fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json().catch(() => ({}))).catch(() => ({}));
    }

    function setSeg(containerId, attr, value) {
        document.querySelectorAll(`#${containerId} .seg`).forEach((b) => {
            b.classList.toggle('active', b.dataset[attr] === value);
        });
    }

    // ---------- HUD ----------
    function renderLegend(k) {
        if (!k) return;
        const rows = [
            ['Place point', k.place],
            ['Undo / Redo', `${k.undo} / ${k.redo}`],
            ['Feet / Aim', k.mode],
            ['Insert at edge', k.insert],
            ['Grab / move', k.grab],
            ['Delete point', k.del],
            ['New zone', k.new],
            ['Select zone', k.select],
            ['Zone type', k.type],
            ['Anchor', k.anchor],
            ['Grid snap', k.snap],
            ['Height +/-', `${k.raise} / ${k.lower}`],
            ['Clean view', k.clean],
            ['Menu', k.menu],
        ];
        $('h-legend').innerHTML = rows
            .map(([label, key]) => `<div class="lg"><span>${label}</span><kbd>${key}</kbd></div>`)
            .join('');
    }

    function applyState(d) {
        $('h-name').textContent = `${d.name || 'my_zone'}  ${d.zoneIdx || 1}/${d.zoneTotal || 1}`;
        $('h-type').textContent = TYPE_LABEL[d.zoneType] || d.zoneType || 'polygon';
        $('h-count').textContent = d.count ?? 0;
        $('h-area').textContent = `${d.area ?? 0} m²`;
        let modeTxt = d.mode === 'aim' ? 'aim (crosshair)' : 'feet';
        if (d.insert) modeTxt += ' - INSERT';
        $('h-mode').textContent = modeTxt;
        $('h-height').textContent = `${Number(d.height || 0).toFixed(1)} m - ${d.anchor || 'center'}`;
        $('h-snap').textContent = d.snap ? 'on' : 'off';
        if (d.keys) renderLegend(d.keys);
    }

    // ---------- Menu ----------
    function renderZones(list) {
        list = list || [];
        $('z-count').textContent = list.length;
        const box = $('m-zones');
        box.innerHTML = list
            .map(
                (z, i) =>
                    `<div class="zone-row${z.active ? ' active' : ''}">` +
                    `<span class="zn">${z.name}</span>` +
                    `<span class="zt">${TYPE_LABEL[z.type] || z.type} - ${z.count}</span>` +
                    `<button class="z-edit" data-i="${i + 1}">${z.active ? 'Editing' : 'Edit'}</button>` +
                    `<button class="z-del" data-i="${i + 1}">Del</button></div>`
            )
            .join('');
        box.querySelectorAll('.z-edit').forEach((b) =>
            b.addEventListener('click', () => post('editZone', { index: b.dataset.i }).then(applyMenu))
        );
        box.querySelectorAll('.z-del').forEach((b) =>
            b.addEventListener('click', () => post('deleteZone', { index: b.dataset.i }).then(applyMenu))
        );
    }

    function applyMenu(d) {
        if (!d) return;
        $('m-name').value = d.name || 'my_zone';
        $('m-height').value = Number(d.height || 4).toFixed(1);
        $('m-area').textContent = `${d.area ?? 0} m²`;
        $('m-perim').textContent = `${d.perimeter ?? 0} m`;
        $('m-count').textContent = d.count ?? 0;
        format = d.format || format;
        setSeg('m-type', 'type', d.zoneType || 'poly');
        setSeg('m-anchor', 'anchor', d.anchor || 'center');
        setSeg('m-format', 'format', format);
        const snapBtn = $('m-snap');
        snapBtn.classList.toggle('on', !!d.snap);
        snapBtn.textContent = d.snap ? 'On' : 'Off';
        const valid = !!d.valid;
        $('m-export').disabled = !valid;
        $('m-export').title = valid ? '' : 'Add more points to this zone first';
        renderZones(d.zones);
    }

    function openMenu(d) {
        applyMenu(d);
        $('m-result').classList.add('hidden');
        $('m-code').value = '';
        $('m-saved').textContent = '';
        menu.classList.remove('hidden');
        $('m-name').focus();
        $('m-name').select();
    }

    function closeMenu() {
        menu.classList.add('hidden');
    }

    function showResult(code, note) {
        $('m-code').value = code || '';
        $('m-result').classList.remove('hidden');
        $('m-saved').textContent = note || '';
    }

    // ---------- message bridge ----------
    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        if (msg.resource) RES = msg.resource;
        switch (msg.action) {
            case 'hud':
                hud.classList.toggle('hidden', !msg.show);
                if (!msg.show) closeMenu();
                break;
            case 'state':
                applyState(msg.data || {});
                break;
            case 'openMenu':
                openMenu(msg.data || {});
                break;
            case 'closeMenu':
                closeMenu();
                break;
            case 'saveResult':
                if (!$('m-result').classList.contains('hidden')) {
                    $('m-saved').textContent = msg.ok
                        ? 'Saved to the output/ folder'
                        : 'Save failed (check server console)';
                }
                break;
        }
    });

    // ---------- UI events ----------
    $('m-close').addEventListener('click', () => post('close'));

    document.querySelectorAll('#m-type .seg').forEach((b) =>
        b.addEventListener('click', () => post('setType', { zoneType: b.dataset.type }).then(applyMenu))
    );
    document.querySelectorAll('#m-anchor .seg').forEach((b) =>
        b.addEventListener('click', () => post('setAnchor', { anchor: b.dataset.anchor }).then(applyMenu))
    );
    document.querySelectorAll('#m-format .seg').forEach((b) =>
        b.addEventListener('click', () => {
            format = b.dataset.format;
            setSeg('m-format', 'format', format);
            post('setFormat', { format });
            // hide stale code so the user can't copy the previous format's output
            $('m-result').classList.add('hidden');
            $('m-code').value = '';
            $('m-saved').textContent = '';
        })
    );

    $('m-snap').addEventListener('click', () => {
        const turnOn = !$('m-snap').classList.contains('on');
        post('setSnap', { snap: turnOn }).then(applyMenu);
    });

    $('m-name').addEventListener('change', () => {
        post('setName', { name: $('m-name').value }).then((r) => {
            if (r && r.name) $('m-name').value = r.name;
        });
    });

    $('m-height').addEventListener('change', () => {
        post('setHeight', { height: parseFloat($('m-height').value) }).then((r) => {
            if (r && r.height != null) $('m-height').value = Number(r.height).toFixed(1);
        });
    });

    $('m-clear').addEventListener('click', () => post('clear').then(applyMenu));

    $('m-newzone').addEventListener('click', () => post('newZone').then(applyMenu));

    $('m-export').addEventListener('click', () => {
        post('export', { name: $('m-name').value, format }).then((r) => {
            if (!r || r.error) return;
            showResult(r.code, 'Code generated below - saving...');
        });
    });

    $('m-exportall').addEventListener('click', () => {
        post('exportAll', { format }).then((r) => {
            if (!r || r.error) return;
            showResult(r.code, `Generated ${r.count} zone(s) - saving...`);
        });
    });

    $('m-copy').addEventListener('click', () => {
        const ta = $('m-code');
        ta.select();
        ta.setSelectionRange(0, ta.value.length);
        const btn = $('m-copy');
        const markCopied = () => {
            btn.textContent = 'Copied!';
            btn.classList.add('done');
            setTimeout(() => { btn.textContent = 'Copy'; btn.classList.remove('done'); }, 1400);
        };
        let ok = false;
        try { ok = document.execCommand('copy'); } catch (_) {}
        if (ok) {
            markCopied();
        } else if (navigator.clipboard) {
            navigator.clipboard.writeText(ta.value).then(markCopied).catch(() => { btn.textContent = 'Press Ctrl+C'; });
        } else {
            btn.textContent = 'Press Ctrl+C';
        }
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !menu.classList.contains('hidden')) post('close');
    });
})();
