LATEX=pdflatex
SOURCES=preamble.tex syntax.tex semantics.tex foundations.tex extensions.tex theorems.tex
TARGET=math-coding.pdf

.PHONY: all clean

all: $(TARGET)

$(TARGET): math-coding.tex $(SOURCES)
	$(LATEX) math-coding.tex
	$(LATEX) math-coding.tex

clean:
	rm -f *.aux *.log *.out *.toc $(TARGET)

# Render LaTeX to HTML via pandoc + MathJax (for the website).
html: math-coding.tex $(SOURCES)
	pandoc math-coding.tex \
		--mathjax \
		--standalone \
		--metadata lang=en \
		-o ../render/index.html