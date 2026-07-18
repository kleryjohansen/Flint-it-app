#!/bin/bash
cd "/Users/zain/Academy/Challenge 4/Flint-it-app"

awk '
/^    @Environment/ {
    print $0;
    if (!added) {
        print "    @ObservedObject private var watchSession = WatchSessionManager.shared"
        added = 1
    }
    next
}
{print $0}
' phoneBuild/Features/Workout/Views/DiscoveryView.swift > temp_discovery.swift && mv temp_discovery.swift phoneBuild/Features/Workout/Views/DiscoveryView.swift

git commit -am "Fix missing watchSession property in DiscoveryView"
git push
