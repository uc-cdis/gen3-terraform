FROM ghcr.io/dineshba/tf-summarize:0.3.7-amd64 AS tf-summarize

FROM hashicorp/terraform:latest 


WORKDIR /workspace

COPY *.tf .

COPY aws aws


COPY dockerrun.sh .

COPY --from=tf-summarize /bin/tf-summarize /bin/tf-summarize

ENTRYPOINT [ "/bin/sh" ]

CMD [ "./dockerrun.sh"]