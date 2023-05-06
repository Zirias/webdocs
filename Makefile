DOCS:=	c/beginners-guide-away-from-scanf \
	freebsd/advocacy \
	freebsd/oracle-aarch64-testbuilder

PANDOC?=pandoc
PDFLAGS?=-s -H style.html -M document-css=false -f markdown -t html5
OUTDIR?=html

OUTDOCS:=$(addprefix $(OUTDIR)/,$(addsuffix .html,$(DOCS)))
DIRS:=$(sort $(addprefix $(OUTDIR)/,$(dir $(DOCS))))

all: $(OUTDOCS)

$(DIRS):
	mkdir -p $(DIRS)

$(OUTDIR)/%.html: %.md Makefile style.html | $(DIRS)
	@echo "  [PANDOC] $@"
	@$(PANDOC) $(PDFLAGS) <$< >$@

clean:
	rm -fr $(OUTDIR)

.PHONY: all clean
