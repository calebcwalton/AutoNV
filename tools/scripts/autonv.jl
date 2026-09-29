using AutoNV
try
    exit(AutoNV.main())
catch err
    if err isa InterruptException
        println(stderr, "AutoNV interrupted. Resume the saved campaign when ready.")
        exit(130)
    end
    showerror(stderr, err)
    println(stderr)
    exit(1)
end
