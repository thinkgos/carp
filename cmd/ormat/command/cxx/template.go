package cxx

import (
	"embed"
	"errors"
	"text/template"

	"github.com/thinkgos/carp"
	"github.com/thinkgos/carp/utils"
)

//go:embed template/*.tpl
var Static embed.FS

var TemplateFuncs = template.FuncMap{
	"add":            func(a, b int) int { return a + b },
	"snakeCase":      utils.SnakeCase,
	"kebabCase":      utils.Kebab,
	"pascalCase":     utils.PascalCase,
	"smallCamelCase": utils.SmallCamelCase,
	"styleName":      utils.StyleName,
}
var (
	tpl = template.Must(template.New("components").
		Funcs(TemplateFuncs).
		ParseFS(Static, "template/*.tpl"))
	dalGormGenericTpl = tpl.Lookup("dal_generic.tpl")
	dalGormTpl        = tpl.Lookup("dal_gorm.tpl")
	dalQueryTpl       = tpl.Lookup("dal_query.tpl")
	dalOptionTpl      = tpl.Lookup("dal_option.tpl")
)

type Dal struct {
	Package     string
	Imports     []string
	ModelPrefix string
	QueryPrefix string
	RepoPrefix  string
	Style       string
	Entity      *carp.EntityDescriptor
}

func GetDalUsedTemplate(t string) (*template.Template, error) {
	switch t {
	case "builtin-gorm":
		return dalGormTpl, nil
	case "builtin-generic":
		return dalGormGenericTpl, nil
	default:
		t, err := ParseTemplateFromFile(t)
		if err != nil {
			return nil, err
		}
		return t, nil
	}
}

func ParseTemplateFromFile(filename string) (*template.Template, error) {
	if filename == "" {
		return nil, errors.New("required template filename")
	}
	tt, err := template.New("custom").
		Funcs(TemplateFuncs).
		ParseFiles(filename)
	if err != nil {
		return nil, err
	}
	ts := tt.Templates()
	if len(ts) == 0 {
		return nil, errors.New("not found any template")
	}
	return ts[0], nil
}
