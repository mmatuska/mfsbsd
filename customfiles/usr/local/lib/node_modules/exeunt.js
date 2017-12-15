/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/*
 * Copyright 2017 Joyent, Inc.
 */

'use strict';


var NODE_MINOR_VER_WITHOUT_PROCESS_EXIT_CODE = 10;


function setBlocking() {
    [process.stdout, process.stderr].forEach(function setStreamBlocking(s) {
        if (s && s._handle && s._handle.setBlocking) {
            s._handle.setBlocking(true);
        }
    });
}


/*
 * A "soft" version of `process.exit([code])` that will avoid actually using
 * `process.exit` if possible -- only if exiting non-zero and with an older
 * version of node (<= 0.10) that doesn't yet support `process.exitCode`.
 *
 * See the discussion in "Solution 1" of the README.md.
 *
 * Usage:
 *      var exeunt = require('exeunt');
 *      // ...
 *      exeunt.softExit(code);
 *      return;
 *
 * @param {Number} code - Optional exit code. Defaults to 0.
 */
function softExit(code) {
    var exitCode = code || 0;
    var nodeVer = process.versions.node.split('.').map(Number);
    var supportsProcessExitCode = true;

    if (nodeVer[0] === 0
        && nodeVer[1] <= NODE_MINOR_VER_WITHOUT_PROCESS_EXIT_CODE) {
        supportsProcessExitCode = false;
    }

    if (supportsProcessExitCode) {
        process.exitCode = exitCode;
    } else if (exitCode !== 0) {
        process.exit(exitCode);
    }
}


/*
 * Set stdout and stderr blocking and then `process.exit()` asynchronously to
 * allow stdout and stderr to flush before process termination.
 *
 * Call this function as follows:
 *      exeunt([code]);
 *      return;
 * instead of:
 *      process.exit([code]);
 * to attempt to ensure stdout/stderr are flushed before exiting.
 *
 * Note that this isn't perfect. See the README.md for considerations. This
 * function corresponds to "Solution 4" described there.
 *
 * @param {Number} code - Optional exit code. Defaults to 0.
 */
function exeunt(code) {
    var exitCode = code || 0;

    // Set stdout and stderr to be blocking *before* we exit...
    setBlocking();

    // ...then exit. However, we must do so in a way that node (libuv) will
    // do another pass through the event loop to handle async IO (in
    // `uv__io_poll`).
    setImmediate(function processExit() {
        process.exit(exitCode);
    });
}


module.exports = exeunt;
module.exports.softExit = softExit;
