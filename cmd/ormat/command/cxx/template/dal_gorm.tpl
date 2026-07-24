package {{.Package}}

import (
    "context"
    
    "gorm.io/gorm"

{{- range $e := .Imports}}
    {{- if ne $e ""}}
    "{{$e}}"
    {{- end}}
{{- end}}
)

{{- $e := .Entity}}
{{- $stName := pascalCase $e.Name}}
{{- $mdPrefix := .ModelPrefix}}
{{- $queryPrefix := .QueryPrefix}}
{{- $mdName := printf "%s%s" $mdPrefix $stName}}

var _ {{$stName}}Dal = {{$stName}}{}

type {{$stName}}Dal interface {
    Create(ctx context.Context, v ...*{{$mdName}}) (int64, error)
    Delete(ctx context.Context, id ...int64) (int64, error)
    DeleteByFilter(ctx context.Context, q *{{$queryPrefix}}Delete{{$stName}}ByFilter) (int64, error)
    UpdateFull(ctx context.Context, v *{{$mdName}}) (int64, error)
    UpdatePartial(ctx context.Context, v *{{$queryPrefix}}Update{{$stName}}ByPartial) (int64, error) 
    Get(ctx context.Context, id int64, funcs ...DalCondition) (*{{$mdName}}, error)
    GetByFilter(ctx context.Context, q *{{$queryPrefix}}Get{{$stName}}ByFilter, funcs ...DalCondition) (*{{$mdName}}, error) 
    ExistByFilter(ctx context.Context, q *{{$queryPrefix}}Exist{{$stName}}ByFilter, funcs ...DalCondition) (bool, error) 
    Count(ctx context.Context, q *{{$queryPrefix}}List{{$stName}}ByFilter) (int64, error) 
    List(ctx context.Context, q *{{$queryPrefix}}List{{$stName}}ByFilter) ([]*{{$mdName}}, error)
    ListPage(ctx context.Context, q *{{$queryPrefix}}List{{$stName}}ByFilter) ([]*{{$mdName}}, int64, error)
    PluckIdByFilter(ctx context.Context, q *{{$queryPrefix}}Pluck{{$stName}}ByFilter) ([]int64, error)
}

type {{$stName}} struct {
	db *gorm.DB
}

func New{{$stName}}(db *gorm.DB) {{$stName}}Dal {
    return {{$stName}} {
        db: db,
    }
}

func (b {{$stName}}) Create(ctx context.Context, v ...*{{$mdName}}) (int64, error) {
    res := b.db.Create(v)
    return res.RowsAffected, res.Error
}

func (b {{$stName}}) Delete(ctx context.Context, id ...int64) (int64, error) {
    res := b.db.Model(&{{$mdName}}{}).
            Scopes(func(db *gorm.DB) *gorm.DB {
                if len(id) == 1 {
                    db =  db.Where("id = ?", id[0])
                }else {
                    db = db.Where("id IN ?", id)
                }
                return db
            }).
            Delete(&{{$mdName}}{})
    return res.RowsAffected, res.Error
}

func (b {{$stName}}) DeleteByFilter(ctx context.Context, q *{{$queryPrefix}}Delete{{$stName}}ByFilter) (int64, error) {
    res := b.db.Model(&{{$mdName}}{}).
            Scopes(b.deleteInnerByFilter(q)).
            Delete(&{{$mdName}}{})
    return res.RowsAffected, res.Error
}


func (b {{$stName}}) UpdateFull(ctx context.Context, v *{{$mdName}}) (int64, error) {
    res := b.db.Model(&{{$mdName}}{}).
            Select("*").
            Where("id = ?", v.Id).
            Updates(v)
    return res.RowsAffected, res.Error
}

func (b {{$stName}}) UpdatePartial(ctx context.Context, v *{{$queryPrefix}}Update{{$stName}}ByPartial) (int64, error) {
    up := make(map[string]any, {{add (len $stName) 8}})
{{- range $f := $e.Fields}}
    {{- if and (ne $f.GoName "CreatedAt") (ne $f.GoName "UpdatedAt") (ne $f.GoName "DeletedAt") (ne $f.GoName "Id")}}
    if v.{{$f.GoName}} != nil {
        up["{{$f.ColumnName}}"] = *v.{{$f.GoName}}
    }
    {{- end}}
{{- end}}
    if len(up) == 0 {
        return 0, nil
    }
    res := b.db.Model(&{{$mdName}}{}).
            Where("id = ?", v.Id).
            Updates(up)
    return res.RowsAffected, res.Error
}

func (b {{$stName}}) Get(ctx context.Context, id int64, funcs ...DalCondition) (*{{$mdName}}, error) {
    var row {{$mdName}}
    
    err := b.db.Model(&{{$mdName}}{}).
            Scopes(funcs...).
            Where("id = ?", id).
            Take(&row).Error
    if err != nil {
        return nil, err
    }
    return &row, nil
}

func (b {{$stName}}) GetByFilter(ctx context.Context, q *{{$queryPrefix}}Get{{$stName}}ByFilter, funcs ...DalCondition) (*{{$mdName}}, error) {
    var row {{$mdName}}
    
    err := b.db.Model(&{{$mdName}}{}).
            Scopes(funcs...).
            Scopes(b.getInnerByFilter(q)).
            Take(&row).Error
    if err != nil {
        return nil, err
    }
    return &row, nil
}

func (b {{$stName}}) ExistByFilter(ctx context.Context, q *{{$queryPrefix}}Exist{{$stName}}ByFilter, funcs ...DalCondition) (existed bool, err error) {
    err = b.db.Model(&{{$mdName}}{}).
            Select("1").
            Scopes(funcs...).
            Scopes(b.existInnerByFilter(q)).
            Limit(1).
            Scan(&existed).Error
    return existed, err
}

func (b {{$stName}}) Count(ctx context.Context, q *{{$queryPrefix}}List{{$stName}}ByFilter) (total int64, err error) {
    err = b.db.Model(&{{$mdName}}{}).
            Scopes(b.listInnerByFilter(q)).
            Count(&total).Error
    return total, err
}

func (b {{$stName}}) List(ctx context.Context, q *{{$queryPrefix}}List{{$stName}}ByFilter) ([]*{{$mdName}}, error) {
    var rows []*{{$mdName}}
    
    err := b.db.Model(&{{$mdName}}{}).
            Scopes(b.listInnerByFilter(q), Limit(q.Page, q.PerPage)).
            Find(&rows).Error
    return rows, err
}

func (b {{$stName}}) ListPage(ctx context.Context, q *{{$queryPrefix}}List{{$stName}}ByFilter) ([]*{{$mdName}}, int64, error) {
    var total int64
    var rows []*{{$mdName}}
    
    db := b.db.Model(&{{$mdName}}{}).
          Scopes(b.listInnerByFilter(q))

    err := db.Count(&total).Error
    if err != nil {
        return nil, 0, err
    }
    if total > 0 {
        err = db.Scopes(Pagination(q.Page, q.PerPage)).
                Find(&rows).Error
        if err != nil {
            return nil, 0, err
        }
    }
    return rows, total, nil
}

func (b {{$stName}}) PluckIdByFilter(ctx context.Context, q *{{$queryPrefix}}Pluck{{$stName}}ByFilter) ([]int64, error) {
    var rows []int64

    err := b.db.Model(&{{$mdName}}{}).
        Scopes(b.pluckInnerByFilter(q)).
        Pluck("id", &rows).Error
    return rows, err
}

func (b {{$stName}}) deleteInnerByFilter(q *{{$queryPrefix}}Delete{{$stName}}ByFilter) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
{{- range $f := $e.Fields}}
    {{- if and (ne $f.GoName "CreatedAt") (ne $f.GoName "UpdatedAt") (ne $f.GoName "DeletedAt")}}
    {{- if eq $f.Type.Type 15 }}
        if q.{{$f.GoName}} != "" {
    {{- else if eq $f.Type.Type 18 }}
        if !q.{{$f.GoName}}.IsZero() {
    {{- else if eq $f.Type.Type 1 }}
        if q.{{$f.GoName}} != nil {
    {{- else }}
        if q.{{$f.GoName}} != 0 {
    {{- end}}
            db = db.Where("{{$f.ColumnName}} = ?", {{if eq $f.Type.Type 1 }}*{{- end}}q.{{$f.GoName}})
        }
    {{- end}}
{{- end}}
        return db
    }
}

func (b {{$stName}}) getInnerByFilter(q *{{$queryPrefix}}Get{{$stName}}ByFilter) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        {{- range $f := $e.Fields}}
            {{- if and (ne $f.GoName "CreatedAt") (ne $f.GoName "UpdatedAt") (ne $f.GoName "DeletedAt")}}
            {{- if eq $f.Type.Type 15 }}
                if q.{{$f.GoName}} != "" {
            {{- else if eq $f.Type.Type 18 }}
                if !q.{{$f.GoName}}.IsZero() {
            {{- else if eq $f.Type.Type 1 }}
                if q.{{$f.GoName}} != nil {
            {{- else }}
                if q.{{$f.GoName}} != 0 {
            {{- end}}
                    db = db.Where("{{$f.ColumnName}} = ?", {{if eq $f.Type.Type 1 }}*{{- end}}q.{{$f.GoName}})
                }
            {{- end}}
        {{- end}}
                return db
            }
}

func (b {{$stName}}) listInnerByFilter(q *{{$queryPrefix}}List{{$stName}}ByFilter) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
{{- range $f := $e.Fields}}
    {{- if and (ne $f.GoName "CreatedAt") (ne $f.GoName "UpdatedAt") (ne $f.GoName "DeletedAt")}}
    {{- if eq $f.Type.Type 15 }}
        if q.{{$f.GoName}} != "" {
    {{- else if eq $f.Type.Type 18 }}
        if !q.{{$f.GoName}}.IsZero() {
    {{- else if eq $f.Type.Type 1 }}
        if q.{{$f.GoName}} != nil {
    {{- else }}
        if q.{{$f.GoName}} != 0 {
    {{- end}}
            db = db.Where("{{$f.ColumnName}} = ?", {{if eq $f.Type.Type 1 }}*{{- end}}q.{{$f.GoName}})
        }
    {{- end}}
{{- end}}
        return db
    }
}

func (b {{$stName}}) existInnerByFilter(q *{{$queryPrefix}}Exist{{$stName}}ByFilter) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
{{- range $f := $e.Fields}}
    {{- if and (ne $f.GoName "CreatedAt") (ne $f.GoName "UpdatedAt") (ne $f.GoName "DeletedAt")}}
    {{- if eq $f.Type.Type 15 }}
        if q.{{$f.GoName}} != "" {
    {{- else if eq $f.Type.Type 18 }}
        if !q.{{$f.GoName}}.IsZero() {
    {{- else if eq $f.Type.Type 1 }}
        {
    {{- else }}
        if q.{{$f.GoName}} != 0 {
    {{- end}}
            db = db.Where("{{$f.ColumnName}} = ?", {{if eq $f.Type.Type 1 }}*{{- end}}q.{{$f.GoName}})
        }
    {{- end}}
{{- end}}
        return db
    }
}

func (b {{$stName}}) pluckInnerByFilter(q *{{$queryPrefix}}Pluck{{$stName}}ByFilter) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
{{- range $f := $e.Fields}}
    {{- if and (ne $f.GoName "CreatedAt") (ne $f.GoName "UpdatedAt") (ne $f.GoName "DeletedAt")}}
    {{- if eq $f.Type.Type 15 }}
        if q.{{$f.GoName}} != "" {
    {{- else if eq $f.Type.Type 18 }}
        if !q.{{$f.GoName}}.IsZero() {
    {{- else if eq $f.Type.Type 1 }}
        if q.{{$f.GoName}} != nil {
    {{- else }}
        if q.{{$f.GoName}} != 0 {
    {{- end}}
            db = db.Where("{{$f.ColumnName}} = ?", {{if eq $f.Type.Type 1 }}*{{- end}}q.{{$f.GoName}})
        }
    {{- end}}
{{- end}}
        return db
    }
}