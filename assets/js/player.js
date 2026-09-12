'use strict';

/*
 * Minimal wrapper around the youtube-nocookie.com <iframe> player.
 *
 * Invidious does not stream any media itself: the iframe does all the
 * playback. This file only talks to it over the postMessage channel that
 * YouTube's embed exposes when `enablejsapi=1` is set, so no third-party
 * script is ever loaded on the page. It exposes a tiny `player` object with
 * the handful of methods the rest of the frontend relies on
 * (`on('ended')`, `off('ended')`, `currentTime(seconds)`).
 */

var video_data = JSON.parse(document.getElementById('video_data').textContent);
var player_data = JSON.parse(document.getElementById('player_data').textContent);

var player = (function () {
    var iframe = document.getElementById('player');
    var origin = player_data.origin;

    var STATE_ENDED = 0;

    var listeners = {};
    var ready = false;
    var pending = [];
    var listenTimer = null;

    function post(message) {
        if (!iframe || !iframe.contentWindow) return;
        iframe.contentWindow.postMessage(JSON.stringify(message), origin);
    }

    function command(func, args) {
        var message = {event: 'command', func: func, args: args || []};
        if (ready) post(message);
        else pending.push(message);
    }

    function flush() {
        while (pending.length) post(pending.shift());
    }

    // Ask the embedded player to start sending us events. YouTube's own
    // IFrame API sends this exact message once the frame has loaded.
    function subscribe() {
        post({event: 'listening', id: 1, channel: 'widget'});
    }

    function startSubscribing() {
        stopSubscribing();
        subscribe();
        // Re-send a few times in case the frame was not ready yet.
        var attempts = 0;
        listenTimer = setInterval(function () {
            attempts++;
            if (ready || attempts > 20) return stopSubscribing();
            subscribe();
        }, 500);
    }

    function stopSubscribing() {
        if (listenTimer !== null) {
            clearInterval(listenTimer);
            listenTimer = null;
        }
    }

    function emit(name) {
        var handlers = listeners[name] || [];
        for (var i = 0; i < handlers.length; i++) {
            try { handlers[i](); } catch (e) { console.error(e); }
        }
    }

    window.addEventListener('message', function (event) {
        if (event.origin !== origin) return;
        if (!iframe || event.source !== iframe.contentWindow) return;

        var data;
        try { data = JSON.parse(event.data); } catch (e) { return; }
        if (!data || typeof data.event !== 'string') return;

        if (!ready) {
            ready = true;
            stopSubscribing();
            flush();
        }

        if (data.event === 'onStateChange' && data.info === STATE_ENDED) {
            emit('ended');
        }
    });

    if (iframe) {
        iframe.addEventListener('load', startSubscribing);
        startSubscribing();
    }

    return {
        on: function (name, handler) {
            (listeners[name] = listeners[name] || []).push(handler);
        },
        off: function (name, handler) {
            if (!listeners[name]) return;
            if (!handler) { listeners[name] = []; return; }
            listeners[name] = listeners[name].filter(function (h) { return h !== handler; });
        },
        currentTime: function (seconds) {
            if (seconds === undefined) return;
            command('seekTo', [Number(seconds), true]);
            command('playVideo');
        },
        play: function () { command('playVideo'); },
        pause: function () { command('pauseVideo'); }
    };
})();
