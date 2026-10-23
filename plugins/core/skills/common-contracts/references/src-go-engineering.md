# Src Go Engineering

### Storage stays inside the owning service's infrastructure (R45)

Database/table/collection access belongs to each service's
`infrastructure` tree. Do not create shared integration/tool packages
that directly reach multiple services' storage. Duplication is
acceptable here because it preserves ownership boundaries. Expose
required behavior through consumer-local interfaces.
