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
{{- $repoPrefix := .RepoPrefix}}
{{- $mdName := printf "%s%s" $mdPrefix $stName}}

var _ {{$stName}}Dal = {{$stName}}{}

type {{$stName}}Dal interface {
    Create(ctx context.Context, v ...*{{$mdName}}) error
    Delete(ctx context.Context, id ...int64) (int, error)
    DeleteByFilter(ctx context.Context, q *{{$queryPrefix}}Delete{{$stName}}ByFilter) (int, error) 
    UpdateFull(ctx context.Context, v *{{$mdName}}) (int, error)
    UpdatePartial(ctx context.Context, v *{{$queryPrefix}}Update{{$stName}}ByPartial) (int, error) 
    Get(ctx context.Context, id int64, opts ...clause.Expression) (*{{$mdName}}, error)
    GetByFilter(ctx context.Context, q *{{$queryPrefix}}Get{{$stName}}ByFilter, opts ...clause.Expression) (*{{$mdName}}, error) 
    ExistByFilter(ctx context.Context, q *{{$queryPrefix}}Exist{{$stName}}ByFilter, opts ...clause.Expression) (bool, error) 
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

func (b {{$stName}}) Create(ctx context.Context, v ...*{{$mdName}}) error {
    return gorm.G[*{{$mdName}}](b.db).CreateInBatches(ctx, &v, 200)
}

func (b {{$stName}}) Delete(ctx context.Context, id ...int64) (int, error) {
    return gorm.G[*{{$mdName}}](b.db).
        Where({{$repoPrefix}}{{$stName}}.Id.In(id...)).
        Delete(ctx)
}

func (b {{$stName}}) DeleteByFilter(ctx context.Context, q *{{$queryPrefix}}Delete{{$stName}}ByFilter) (int, error) {
    return gorm.G[*{{$mdName}}](b.db).
        Scopes(b.deleteInnerByFilter(q)).
        Delete(ctx)
}

func (b {{$stName}}) UpdateFull(ctx context.Context, v *{{$mdName}}) (int, error) {
    return gorm.G[*{{$mdName}}](b.db).
            Where({{$repoPrefix}}{{$stName}}.Id.Eq(v.Id)).
            Updates(ctx,v)
}

func (b {{$stName}}) UpdatePartial(ctx context.Context, v *{{$queryPrefix}}Update{{$stName}}ByPartial) (int, error) {
    ref := {{$repoPrefix}}{{$stName}}
	ups := make([]clause.Assigner, 0, 16)
{{- range $f := $e.Fields}}
    {{- if and (ne $f.GoName "CreatedAt") (ne $f.GoName "UpdatedAt") (ne $f.GoName "DeletedAt") (ne $f.GoName "Id")}}
    if v.{{$f.GoName}} != nil {
        ups = append(ups, ref.{{$f.GoName}}.Set(*v.{{$f.GoName}}))
    }
    {{- end}}
{{- end}}
    if len(ups) == 0 {
        return 0, nil
    }
    return gorm.G[*{{$mdName}}](b.db).
        Where(ref.Id.Eq(v.Id)).
        Set(ups...).
        Update(ctx)
}

func (b {{$stName}}) Get(ctx context.Context, id int64, opts ...clause.Expression) (*{{$mdName}}, error) {
    return gorm.G[*{{$mdName}}](b.db, opts...).
        Where({{$repoPrefix}}{{$stName}}.Id.Eq(id)).
        Take(ctx)
}

func (b {{$stName}}) GetByFilter(ctx context.Context, q *{{$queryPrefix}}Get{{$stName}}ByFilter, opts ...clause.Expression) (*{{$mdName}}, error) {
    return gorm.G[*{{$mdName}}](b.db, opts...).
        Scopes(b.getInnerByFilter(q)).
        Take(ctx)
}

func (b {{$stName}}) ExistByFilter(ctx context.Context, q *{{$queryPrefix}}Exist{{$stName}}ByFilter, opts ...clause.Expression) (existed bool, err error) {
    err = gorm.G[*{{$mdName}}](b.db, opts...).
		Select("1").
		Limit(1).
        Scopes(b.existInnerByFilter(q)).
        Scan(ctx, &existed)
    return existed, err
}

func (b {{$stName}}) Count(ctx context.Context, q *{{$queryPrefix}}List{{$stName}}ByFilter) (int64, error) {
    return gorm.G[*{{$mdName}}](b.db).
        Scopes(b.listInnerByFilter(q)).
        Count(ctx, "*")
}


func (b {{$stName}}) List(ctx context.Context, q *{{$queryPrefix}}List{{$stName}}ByFilter) ([]*{{$mdName}}, error) {
    return gorm.G[*{{$mdName}}](b.db).
        Scopes(
            b.listInnerByFilter(q),
            Limit(q.Page, q.PerPage),
        ).
        Find(ctx)
}

func (b {{$stName}}) ListPage(ctx context.Context, q *{{$queryPrefix}}List{{$stName}}ByFilter) ([]*{{$mdName}}, int64, error) {
    total, err := gorm.G[*{{$mdName}}](b.db).
        Scopes(b.listInnerByFilter(q)).
        Count(ctx, "*")
	if err != nil {
		return nil, 0, err
	}
    rows, err := gorm.G[*{{$mdName}}](b.db).
        Scopes(
            b.listInnerByFilter(q),
            Pagination(q.Page, q.PerPage),
        ).
        Find(ctx)
	if err != nil {
		return nil, 0, err
	}
	return rows, total, nil
}

func (b {{$stName}}) PluckIdByFilter(ctx context.Context, q *{{$queryPrefix}}Pluck{{$stName}}ByFilter) (rows []int64,err error) {
    ref := {{$repoPrefix}}{{$stName}}
    err = gorm.G[*{{$mdName}}](b.db).
        Select(rapier.BuildSelect(ref.Id)).
        Scopes(b.pluckInnerByFilter(q)).
        Scan(ctx, &rows)
	return rows, err
}


func (b {{$stName}}) deleteInnerByFilter(q *{{$queryPrefix}}Delete{{$stName}}ByFilter) func(stmt *gorm.Statement) {
    return func(stmt *gorm.Statement) {
        ref := {{$repoPrefix}}{{$stName}}
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
            stmt.Where(ref.{{$f.GoName}}.Eq({{if eq $f.Type.Type 1 }}*{{- end}}q.{{$f.GoName}}))
        }
    {{- end}}
{{- end}}
    }
}

func (b {{$stName}}) getInnerByFilter(q *{{$queryPrefix}}Get{{$stName}}ByFilter) func(stmt *gorm.Statement) {
    return func(stmt *gorm.Statement) {
        ref := {{$repoPrefix}}{{$stName}}
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
                    stmt.Where(ref.{{$f.GoName}}.Eq({{if eq $f.Type.Type 1 }}*{{- end}}q.{{$f.GoName}}))
                }
            {{- end}}
        {{- end}}
    }
}
func (b {{$stName}}) existInnerByFilter(q *{{$queryPrefix}}Exist{{$stName}}ByFilter) func(stmt *gorm.Statement) {
    return func(stmt *gorm.Statement) {
        ref := {{$repoPrefix}}{{$stName}}
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
            stmt.Where(ref.{{$f.GoName}}.Eq({{if eq $f.Type.Type 1 }}*{{- end}}q.{{$f.GoName}}))
        }
    {{- end}}
{{- end}}
    }
}
func (b {{$stName}}) listInnerByFilter(q *{{$queryPrefix}}List{{$stName}}ByFilter) func(stmt *gorm.Statement) {
    return func(stmt *gorm.Statement) {
        ref := {{$repoPrefix}}{{$stName}}
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
            stmt.Where(ref.{{$f.GoName}}.Eq({{if eq $f.Type.Type 1 }}*{{- end}}q.{{$f.GoName}}))
        }
    {{- end}}
{{- end}}
    }
}

func (b {{$stName}}) pluckInnerByFilter(q *{{$queryPrefix}}Pluck{{$stName}}ByFilter) func(stmt *gorm.Statement) {
    return func(stmt *gorm.Statement) {
        ref := {{$repoPrefix}}{{$stName}}
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
            stmt.Where(ref.{{$f.GoName}}.Eq({{if eq $f.Type.Type 1 }}*{{- end}}q.{{$f.GoName}}))
        }
    {{- end}}
{{- end}}
    }
}