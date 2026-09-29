# Local-only smoke check: never sends a network request or invokes an LLM.
using Sockets
workspace, forbidden = ARGS
write(joinpath(workspace, "allowed.txt"), "allowed")
denied_write = try
    write(forbidden, "sandbox did not enforce sibling protection")
    false
catch
    true
end
denied_network = try
    server = listen(ip"127.0.0.1", 0)
    close(server)
    false
catch
    true
end
denied_write && denied_network || error("sandbox failed to restrict writes or local network binding")
println("sandbox restrictions verified")
