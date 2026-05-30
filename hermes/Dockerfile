FROM nousresearch/hermes-agent:latest

RUN uv pip install --python /opt/hermes/.venv/bin/python "honcho-ai>=2.0.1"

COPY patches/patch_codex_stream.py /tmp/patch_codex_stream.py
RUN /opt/hermes/.venv/bin/python /tmp/patch_codex_stream.py && rm /tmp/patch_codex_stream.py
