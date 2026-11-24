# Railway template: cap onnxruntime's thread pools (pymupdf-layout opens two
# InferenceSessions at import; by default each starts one thread per host core).
import os

def _patch_ort():
    try:
        n = int(os.environ.get("ORT_INTRA_OP_THREADS") or os.environ.get("OMP_NUM_THREADS") or 0)
    except ValueError:
        n = 0
    if n <= 0:
        return
    import builtins
    _orig_import = builtins.__import__
    state = {"done": False}

    def _import(name, globals=None, locals=None, fromlist=(), level=0):
        mod = _orig_import(name, globals, locals, fromlist, level)
        if not state["done"] and name.startswith("onnxruntime"):
            import sys
            ort = sys.modules.get("onnxruntime")
            if ort is not None and hasattr(ort, "InferenceSession"):
                state["done"] = True
                base = ort.InferenceSession

                class InferenceSession(base):
                    def __init__(self, path_or_bytes, sess_options=None, *args, **kwargs):
                        if sess_options is None:
                            sess_options = ort.SessionOptions()
                        sess_options.intra_op_num_threads = n
                        sess_options.inter_op_num_threads = 1
                        sess_options.enable_cpu_mem_arena = False
                        super().__init__(path_or_bytes, sess_options, *args, **kwargs)

                ort.InferenceSession = InferenceSession
                builtins.__import__ = _orig_import
        return mod

    builtins.__import__ = _import

_patch_ort()


def _patch_subprocess():
    # Converter jobs (ffmpeg, LibreOffice, Calibre, draw.io, Inkscape, tesseract)
    # run as child processes. Start each through /railway/oomwrap, which sets its
    # oom_score_adj to 1000: if a big file goes over the memory limit, the kernel
    # kills that one job (it fails with an error) instead of the web app.
    if os.environ.get("TRANSMUTE_OOM_WRAP") != "1":
        return
    import subprocess
    wrap = "/railway/oomwrap"
    if not os.access(wrap, os.X_OK):
        return
    base_init = subprocess.Popen.__init__

    def __init__(self, args, *a, **kw):
        if isinstance(args, (list, tuple)) and args and str(args[0]) != wrap and not kw.get("shell"):
            args = [wrap, *[str(x) if isinstance(x, os.PathLike) else x for x in args]]
        base_init(self, args, *a, **kw)

    subprocess.Popen.__init__ = __init__


_patch_subprocess()
