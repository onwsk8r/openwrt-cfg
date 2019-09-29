
BEGIN {
    results[""] = 0
    servers[""] = 0
}

{
    if ( $8 != "yes" ) {
        next
    }
    matches[""] = 0
    proto = 4
    match($11, /([[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+):?([[:digit:]]+)?/, matches)
    if ( matches[1] == "" ) {
        match($11, /\[([^\]]+)\]:?([[:digit:]]+)?/, matches)
        proto = 6
    }
    if ( matches[1] == "" ) {
        print "no match for " $1 " given " $11
        next
    }
    if ( matches[2] == "" ) {
        matches[2] = 53
    }
    print "matched " $1 " to " matches[1] " on port " matches[2] " with " proto
    command = "ping -" proto " -c4 -p" matches[2] " " matches[1] " | cut -s -d'/' -f5"
    print command | "/bin/sh"
    close("/bin/sh")
}

# END {
#     asort(results) # The original keys are now gone
#     for ( i = 1; i <= 3; i++ ) {
#        system("uci set dnscrypt-proxy.ns$i.resolver=$servers[$results[i]]")
#     }
#     system("uci commit")
# }
