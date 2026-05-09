# Zed Julia — plot side-pane display helper
#
# Intercepts image-renderable results (Plots.jl, Makie.jl, Images.jl, …)
# and writes them to a fixed path that Zed's image viewer watches.
# Non-image values (numbers, strings, DataFrames, …) fall through to the
# normal REPL display unchanged.
#
# INSTALL (once):
#   Copy this file to ~/.julia/config/zed_plot_display.jl
#   Add to ~/.julia/config/startup.jl:
#
#     try
#         include(joinpath(@__DIR__, "zed_plot_display.jl"))
#     catch err
#         @warn "Failed to load Zed plot display" exception = (err, catch_backtrace())
#     end
#
# USAGE (once per Zed session, after starting a Julia REPL):
#   Run the "Julia: Open Plot Pane" task from Zed's command palette, then
#   drag the opened tab to a side pane.  Subsequent plots auto-refresh in
#   place via Zed's built-in file watcher (~100 ms latency).

# All plots overwrite the same file so Zed's image viewer auto-refreshes
# via fs::watch() without any further CLI invocations.
const _ZED_PLOT_PATH = expanduser("~/.cache/zed-julia/current-plot.png")

# 1×1 transparent PNG — written on first load so the file exists before
# any plot has been generated.
const _ZED_BLANK_PNG = UInt8[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]

struct ZedDisplay <: AbstractDisplay end

# true after the first plot of a session opens the image viewer tab.
const _ZED_PLOT_OPENED = Ref(false)

function _zed_ensure_dir()
    dir = dirname(_ZED_PLOT_PATH)
    isdir(dir) || mkpath(dir)
    isfile(_ZED_PLOT_PATH) || write(_ZED_PLOT_PATH, _ZED_BLANK_PNG)
end

function _zed_write_image(x, mime::MIME)
    open(_ZED_PLOT_PATH, "w") do io
        Base.invokelatest(show, io, mime, x)
    end
end

function _zed_open_viewer()
    cmd = Sys.which("zed")
    cmd === nothing && return false
    try
        run(Cmd([cmd, _ZED_PLOT_PATH]); wait = false)
        return true
    catch
        return false
    end
end

function Base.display(::ZedDisplay, x)
    for mime in (MIME("image/png"), MIME("image/svg+xml"))
        if Base.invokelatest(showable, mime, x)
            _zed_write_image(x, mime)
            if !_ZED_PLOT_OPENED[]
                _ZED_PLOT_OPENED[] = true
                if _zed_open_viewer()
                    printstyled("[Zed] plot pane opened — drag tab to a split for persistent side pane\n";
                                color = :cyan)
                else
                    printstyled("[Zed] plot saved to $_ZED_PLOT_PATH\n"; color = :yellow)
                end
            else
                printstyled("[Zed] plot updated\n"; color = :cyan)
            end
            return
        end
    end
    throw(MethodError(display, (ZedDisplay(), x)))
end

# Guard against double-loading when startup.jl is re-evaluated.
if isinteractive() && !isdefined(Main, :_ZED_DISPLAY_LOADED)
    Main.eval(:(const _ZED_DISPLAY_LOADED = true))
    _zed_ensure_dir()
    # Suppress GR's separate GUI window; PNG workstation writes to io directly.
    get!(ENV, "GKSwstype", "100")
    pushdisplay(ZedDisplay())
    # Plotting libraries (Plots.jl, Makie.jl, …) call pushdisplay() in their
    # __init__, which buries ZedDisplay below their own display.  Re-push
    # ZedDisplay to the top after each package load so it stays highest priority.
    push!(Base.package_callbacks, function(::Base.PkgId)
        d = Base.Multimedia.displays
        isempty(d) && return
        d[end] isa ZedDisplay && return          # already on top
        idx = findfirst(x -> x isa ZedDisplay, d)
        idx === nothing && return
        push!(d, splice!(d, idx))
    end)
end
