MKDOCS = python3 -m mkdocs

HTML_OUTPUT = /var/www/dev-wiki

all:

serve:
	$(MKDOCS) serve

html:
	$(MKDOCS) build

publish:
	ssh root@www.cyub.vip "cd ${HTML_OUTPUT}; git pull"

plugin:
	pip install mkdocs-git-revision-date-localized-plugin # 显示文档编辑时间
	pip install mkdocs-mermaid2-plugin # mermaid图表支持
	pip install mkdocs-charts-plugin # chat
	pip install mkdocs-print-site-plugin # print site
	pip install mkdocs-jupyter # jupyter
	pip install mkdocs-glightbox # image lightbox

