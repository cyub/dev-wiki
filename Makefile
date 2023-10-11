MKDOCS = python3 -m mkdocs

all:

serve:
	$(MKDOCS) serve

html:
	$(MKDOCS) build