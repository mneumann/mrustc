/*
 */
#include "types.hpp"
#include "ast/ast.hpp"

template <typename T>
inline ::std::ostream& operator<<(::std::ostream& os, const ::std::vector<T>& v) {
    if( v.size() > 0 )
    {
        bool is_first = true;
        for( const auto& i : v )
        {
            if(!is_first)
                os << ", ";
            is_first = false;
            os << i;
        }
    }
    return os;
}


::std::ostream& operator<<(::std::ostream& os, const TypeRef& tr) {
    os << "TypeRef(";
    switch(tr.m_class)
    {
    case TypeRef::ANY:
        os << "TagAny";
        break;
    case TypeRef::UNIT:
        os << "TagUnit";
        break;
    case TypeRef::PRIMITIVE:
        os << "TagPrimitive, " << tr.m_core_type;
        break;
    case TypeRef::TUPLE:
        os << "TagTuple, {" << tr.m_inner_types << "}";
        break;
    case TypeRef::REFERENCE:
        os << "TagReference, " << (tr.m_is_inner_mutable ? "mut" : "const") << ", " << tr.m_inner_types[0];
        break;
    case TypeRef::POINTER:
        os << "TagPointer, " << (tr.m_is_inner_mutable ? "mut" : "const") << ", " << tr.m_inner_types[0];
        break;
    case TypeRef::ARRAY:
        os << "TagSizedArray, " << tr.m_inner_types[0] << ", " << tr.m_size_expr;
        break;
    case TypeRef::GENERIC:
        os << "TagArg, " << tr.m_path[0].name();
        break;
    case TypeRef::PATH:
        os << "TagPath, " << tr.m_path;
        break;
    case TypeRef::ASSOCIATED:
        os << "TagAssoc, <" << tr.m_inner_types[0] << " as " << tr.m_inner_types[1] << ">::" << tr.m_path[0].name();
        break;
    }
    os << ")";
    return os;
}

const char* coretype_name(const eCoreType ct ) {
    switch(ct)
    {
    case CORETYPE_INVAL:return "-";
    case CORETYPE_ANY:  return "_";
    case CORETYPE_CHAR: return "char";
    case CORETYPE_UINT: return "usize";
    case CORETYPE_INT:  return "isize";
    case CORETYPE_U8:   return "u8";
    case CORETYPE_I8:   return "i8";
    case CORETYPE_U16:  return "u16";
    case CORETYPE_I16:  return "i16";
    case CORETYPE_U32:  return "u32";
    case CORETYPE_I32:  return "i32";
    case CORETYPE_U64:  return "u64";
    case CORETYPE_I64:  return "i64";
    case CORETYPE_F32:  return "f32";
    case CORETYPE_F64:  return "f64";
    }
    DEBUG("Unknown core type?! " << ct);
    return "NFI";
}
void operator% (::Serialiser& s, eCoreType ct) {
    s << coretype_name(ct);
}
void operator% (::Deserialiser& d, eCoreType& ct) {
    ::std::string n;
    d.item(n);
    /* */if(n == "-")   ct = CORETYPE_INVAL;
    else if(n == "_")   ct = CORETYPE_ANY;
    else if(n == "char")  ct = CORETYPE_CHAR;
    else if(n == "usize") ct = CORETYPE_UINT;
    else if(n == "isize") ct = CORETYPE_INT;
    else if(n == "u8")    ct = CORETYPE_U8;
    else if(n == "i8")    ct = CORETYPE_I8;
    else if(n == "u16")   ct = CORETYPE_U16;
    else if(n == "i16")   ct = CORETYPE_I16;
    else if(n == "u32")   ct = CORETYPE_U32;
    else if(n == "i32")   ct = CORETYPE_I32;
    else if(n == "u64")   ct = CORETYPE_U64;
    else if(n == "i64")   ct = CORETYPE_I64;
    else if(n == "f32")   ct = CORETYPE_F32;
    else if(n == "f64")   ct = CORETYPE_F64;
    else
        throw ::std::runtime_error("Deserialise failure - coretype " + n);
}
const char* TypeRef::class_name(TypeRef::Class c) {
    switch(c)
    {
    #define _(x)    case TypeRef::x: return #x;
    _(ANY)
    _(UNIT)
    _(PRIMITIVE)
    _(TUPLE)
    _(REFERENCE)
    _(POINTER)
    _(ARRAY)
    _(GENERIC)
    _(PATH)
    _(ASSOCIATED)
    #undef _
    }
    return "NFI";
}
void operator>>(::Deserialiser& d, TypeRef::Class& c) {
    ::std::string n;
    d.item(n);
    #define _(x) if(n == #x) c = TypeRef::x;
    /**/ _(ANY)
    else _(UNIT)
    else _(PRIMITIVE)
    else _(TUPLE)
    else _(REFERENCE)
    else _(POINTER)
    else _(ARRAY)
    else _(GENERIC)
    else _(PATH)
    else _(ASSOCIATED)
    else
        throw ::std::runtime_error("Deserialise failure - " + n);
    #undef _
}
SERIALISE_TYPE(TypeRef::, "TypeRef", {
    s << class_name(m_class);
    if(m_class == PRIMITIVE)
        s << coretype_name(m_core_type);
    s << m_inner_types;
    if(m_class == REFERENCE || m_class == POINTER)
        s << m_is_inner_mutable;
    s << m_size_expr;
    s << m_path;
},{
    s >> m_class;
    if(m_class == PRIMITIVE)
        s % m_core_type;
    s.item( m_inner_types );
    if(m_class == REFERENCE || m_class == POINTER)
        s.item( m_is_inner_mutable );
    bool size_expr_present;
    s.item(size_expr_present);
    if( size_expr_present )
        m_size_expr = AST::ExprNode::from_deserialiser(s);
    else
        m_size_expr.reset();
    s.item( m_path );
})
