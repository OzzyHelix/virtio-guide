#!/bin/bash
echo "this script will fail you must add your name to this and then select the correct version of looking glass
depending if you are using wayland"
echo "Please press Ctrl+Z to Cancel this script and use nano, vim or your prefered editor to edit this"
sleep 120
# after editing remove everything above except for the "#!/bin/bash"
sudo chown <your-username>:libvirt-qemu /dev/shm/looking-glass
sudo chmod 660 /dev/shm/looking-glass
#/usr/bin/scream -i ozzynet &!
for i in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do echo performance | sudo tee $i; done
# both are started in fullscreen with the -F flag
# the first option is for xorg by default its setup for wayland
# uncomment the option you wish to use
env -u WAYLAND_DISPLAY looking-glass-client -F opengl:preventBuffer=0 spice:enable=yes
#looking-glass-client -F opengl:preventBuffer=0 spice:enable=yes

#/usr/bin/looking-glass-client -o -F opengl:preventBuffer=0 spice:enable=yes >/dev/null 2>&1 & # Starts Looking Glass, and ignores all output (We aren't watching anyways)
# /path/to/scream-pulse & # Starts Scream with pulse
# OR
# /path/to/scream-ivshmem-pulse /dev/shm/scream-ivshmem & # Starts Scream with IVSHMEM
#/usr/bin/scream  -m /dev/shm/scream-ivshmem
#wait -n # We wait for any of these processes to exit. (Like closing the Looking Glass window, in our case)
#pkill -P $$ # We kill the remaining processes (In our case, scream)
