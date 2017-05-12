all: slides.html

slides.html: slides.md template.html
	pandoc --section-divs --no-highlight -t revealjs \
		   --template template.html \
	       -s slides.md \
		   -o slides-light.html

#slides.html: slides.md template.html
#	pandoc -t dzslides \
#		   --template template.html \
#	       -s slides.md \
#		   -o slides-light.html

standalone: slides.md template.html
	pandoc -t dzslides \
		   --self-contained \
		   --template template.html \
	       -s slides.md \
		   -o slides.html

clean:
	-rm slides.html
