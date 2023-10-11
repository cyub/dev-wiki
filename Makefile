MKDOCS = python3 -m mkdocs

HTML_OUTPUT = /var/www/dev-wiki

all:

serve:
	$(MKDOCS) serve

html:
	$(MKDOCS) build

publish:
	ssh root@www.cyub.vip "cd ${HTML_OUTPUT}; git pull"

