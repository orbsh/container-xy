use ../../bx *


export def main [context: record = {}] {
    {
        from: 'python:3.12-slim'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: spacy }
    | build {|ctx|
        pkg with [
            rustup
            build-essential
        ] {
            rust up root stable
            pkg pip install [pip setuptools wheel 'spacy[transformers]']
        }
        run ['python -m spacy download zh_core_web_trf']
    }
}
