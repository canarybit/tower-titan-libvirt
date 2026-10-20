package cbclient

default allow := false

# =================================
# claims.metadata.system.os_version
# System version
# =================================
errors contains "claims.metadata.system.os_version" if {
  not input.claims.metadata.system.os_version == "26.04"
}

allow if {
  count(errors) <= 0
}
