package {{.Package}}

import (
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)


func NilOrEmpty[T any](slices []T) []T {
	if slices == nil {
		return make([]T, 0)
	}
	return slices
}

var ErrRecordNotFound = gorm.ErrRecordNotFound

var (
	// DefaultPerPage 默认页大小
	DefaultPerPage = int64(50)
	// DefaultPerPage 默认最大页大小
	DefaultMaxPerPage = int64(500)
)

// Paginate 分页器
// 分页索引: page >= 1
// 分页大小: perPage >= 1 && <= DefaultMaxPerPage
func Paginate(page, perPage int64, maxPerPages ...int64) clause.Expression {
	return paginate(page, perPage, maxPerPages...)
}

func paginate(page, perPage int64, maxPerPages ...int64) clause.Limit {
	maxPerPage := DefaultMaxPerPage
	if len(maxPerPages) > 0 && maxPerPages[0] > 0 {
		maxPerPage = maxPerPages[0]
	}
	if page < 1 {
		page = 1
	}
	switch {
	case perPage < 1:
		perPage = DefaultPerPage
	case perPage > maxPerPage:
		perPage = maxPerPage
	default: // do nothing
	}
	limit, offset := int(perPage), int(perPage*(page-1))
	return clause.Limit{
		Limit:  &limit,
		Offset: offset,
	}
}

// Pagination 分页器
// 分页索引: page >= 1
// 分页大小: perPage >= 1 && <= DefaultMaxPerPage
func Pagination(page, perPage int64, maxPerPages ...int64) func(*gorm.Statement) {
	p := paginate(page, perPage, maxPerPages...)
	return func(stmt *gorm.Statement) {
		stmt.Limit(*p.Limit).
			Offset(p.Offset)
	}
}

// 限制器
// offset = perPage * (page - 1)
// limit = perPage
// if limit > 0: use limit
// if offset > 0: use offset
func Limit(page, perPage int64) func(*gorm.Statement) {
	offset := 0
	if page > 0 {
		offset = int(perPage * (page - 1))
	}
	limit := int(perPage)
	return func(stmt *gorm.Statement) {
		if offset > 0 {
			stmt.Offset(offset)
		}
		if limit > 0 {
			stmt.Limit(limit)
		}
	}
}

// LockingUpdate specify the lock strength to UPDATE
func LockingUpdate() clause.Expression {
	return clause.Locking{Strength: "UPDATE"}
}

// LockingShare specify the lock strength to SHARE
func LockingShare() clause.Expression {
	return clause.Locking{Strength: "SHARE"}
}
