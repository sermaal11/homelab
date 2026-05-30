from pathlib import Path

path = Path("/opt/hermes/run_agent.py")
text = path.read_text()

needle = """            except (_httpx.RemoteProtocolError, _httpx.ReadTimeout, _httpx.ConnectError, ConnectionError) as exc:
"""

patch = """            except TypeError as exc:
                # The ChatGPT Codex backend can stream a complete answer and then
                # finish with a response.completed frame whose response.output is
                # null. openai-python then raises TypeError while parsing the
                # final snapshot, even though we already received useful deltas.
                if (
                    \"'NoneType' object is not iterable\" in str(exc)
                    and not has_tool_calls
                    and (collected_output_items or self._codex_streamed_text_parts)
                ):
                    output_items = list(collected_output_items)
                    if not output_items and self._codex_streamed_text_parts:
                        assembled = \"\".join(self._codex_streamed_text_parts)
                        output_items = [SimpleNamespace(
                            type=\"message\",
                            role=\"assistant\",
                            status=\"completed\",
                            content=[SimpleNamespace(type=\"output_text\", text=assembled)],
                        )]
                    logger.warning(
                        \"Codex stream parser hit null response.output; recovered from %d items and %d text chunks\",
                        len(output_items),
                        len(self._codex_streamed_text_parts),
                    )
                    return SimpleNamespace(
                        type=\"response\",
                        status=\"completed\",
                        model=self.model,
                        output=output_items,
                        output_text=\"\".join(self._codex_streamed_text_parts),
                    )
                raise
""" + needle

if "Codex stream parser hit null response.output" not in text:
    if needle not in text:
        raise SystemExit("patch target not found")
    text = text.replace(needle, patch, 1)
    path.write_text(text)
