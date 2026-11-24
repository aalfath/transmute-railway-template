# Transmute v2.1.1, official image pinned by version and digest.
# Bump both the tag and the digest together, and add a CHANGELOG.md entry.
FROM ghcr.io/transmute-app/transmute:2.1.1@sha256:87b669d835d9e68bdbc4082ab061cb361cd3ecee69c14ccfa9a3814d326b6707

# Small Railway wrapper: start script, first-boot admin, ffmpeg thread cap.
COPY --chmod=755 railway/ /railway/
RUN mv /usr/bin/ffmpeg /usr/bin/ffmpeg.real \
 && cp /railway/ffmpeg /usr/bin/ffmpeg \
 && chmod 755 /usr/bin/ffmpeg \
 && cp /railway/sitecustomize.py /usr/local/lib/python3.13/site-packages/sitecustomize.py \
 && python -c "import sitecustomize"

ENV PORT=3313
EXPOSE 3313
WORKDIR /app
ENTRYPOINT ["/bin/bash", "/railway/start.sh"]
