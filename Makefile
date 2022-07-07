#!make

name="00000000-init"
host="0.0.0.0"
port="1313"
config="config.yml"

new:
	@hugo new "content/$(name)/index.md" --verbose

serve:
	@hugo server -D -E -F --bind ${host} --port ${port} \
		--baseURL "http://${host}:${port}" --noHTTPCache \
		--gc --disableFastRender --verbose --watch --printMemoryUsage \
		--templateMetricsHints --templateMetrics \
		--config ./${config}

list.all:
	@hugo list all --verbose

list.draft:
	@hugo list drafts --verbose

update.theme:
	@git submodule update --init --recursive

