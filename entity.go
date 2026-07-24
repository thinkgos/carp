package carp

import (
	"github.com/thinkgos/carp/proto"
	"github.com/thinkgos/carp/sqlx"
)

// EntityDescriptor Each table corresponds to an EntityDescriptor
type EntityDescriptor struct {
	Name        string                  // entity name
	Comment     string                  // entity comment
	Table       TableDef                // entity table define
	Fields      []*FieldDescriptor      // field information
	Indexes     []*IndexDescriptor      // index information
	ForeignKeys []*ForeignKeyDescriptor // foreign key information
}

func (s *EntityDescriptor) IntoProto() *proto.Message {
	fields := make([]*proto.MessageField, 0, len(s.Fields))
	for _, field := range s.Fields {
		fields = append(fields, field.IntoProto())
	}
	return &proto.Message{
		Name:      s.Name,
		TableName: s.Name,
		Comment:   s.Comment,
		Fields:    fields,
	}
}

func (s *EntityDescriptor) IntoSQL() *sqlx.Table {
	return &sqlx.Table{
		Name:    s.Name,
		Sql:     s.Table.Definition(),
		Comment: s.Comment,
	}
}

type EntityDescriptorSlice []*EntityDescriptor

func (t EntityDescriptorSlice) Len() int           { return len(t) }
func (t EntityDescriptorSlice) Less(i, j int) bool { return t[i].Name < t[j].Name }
func (t EntityDescriptorSlice) Swap(i, j int)      { t[i], t[j] = t[j], t[i] }
