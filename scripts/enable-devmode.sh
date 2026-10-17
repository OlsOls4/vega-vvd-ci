#!/usr/bin/env bash
# Enable VVD developer mode (required for inputd-cli button_press over vda),
# then wait for the guest to reboot and the input channel to answer.
set -uo pipefail
probe() { vega exec vda shell inputd-cli get_screen_size 2>&1 | grep -Eq '[0-9]+ *x *[0-9]+'; }
if probe; then echo "inputd-cli already usable"; exit 0; fi
echo "enabling developer mode (VVD guest reboots)"
vega exec vda shell vsm developer-mode enable 2>&1 || true
sleep 20
for i in $(seq 1 60); do
  if probe; then echo "inputd-cli usable after reboot (${i})"; vega exec vda shell inputd-cli get_screen_size; exit 0; fi
  sleep 5
done
echo "WARNING: inputd-cli still not usable"; vega exec vda shell inputd-cli get_screen_size || true
exit 1
