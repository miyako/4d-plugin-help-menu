#include "4DPluginAPI.h"
#include "PrivateTypes.h"
#include "EntryPoints.h"
#include "4DPlugin-JSON.h"
#include "ARRAY_TEXT.h"
#include "C_TEXT.h"
#include <cassert>
#include <cstdlib>
#include <cstring>
#include <map>
#include <set>
#include <string>
#import "Cocoa/Cocoa.h"

@implementation AuditMenu
- (id)initWithTitle:(NSString *)title {
    if((self = [super init])) self.title = title;
    return self;
}
- (void)removeAllItems {}
- (void)dealloc { [_title release]; [super dealloc]; }
@end
AuditApplication *auditApp;
@implementation AuditApplication
+ (AuditApplication *)sharedApplication { return auditApp; }
- (void)dealloc { [_helpMenu release]; [super dealloc]; }
@end

static std::set<PA_Unichar *> strings;
static std::map<PA_Handle, size_t> handles;
struct Ref { int owners; };
static std::map<void *, int> refs;
static PA_Variable property;
static CUTF16String fixture;
static bool failGet, failHandle, failCommand, nullEmpty;
static int getterStringAccess, clears, mainCalls;

static PA_Unistring makeString(const PA_Unichar *text) {
    size_t units = 0;
    if(text) while(text[units]) ++units;
    PA_Unistring s = {};
    s.fLength = units;
    if(units || !nullEmpty) {
        s.fString = static_cast<PA_Unichar *>(calloc(units + 1, sizeof(PA_Unichar)));
        assert(s.fString);
        if(units) memcpy(s.fString, text, units * sizeof(PA_Unichar));
        PA_Unichar *allocation = s.fString;
        assert(strings.insert(allocation).second);
    }
    return s;
}
static void dispose(PA_Unistring s) {
    PA_Unichar *allocation = s.fString;
    if(allocation) {
        assert(strings.erase(allocation) == 1);
        free(allocation);
    }
}
static void checkString(PA_Unistring s, const CUTF16String &expected) {
    assert(s.fLength == expected.size());
    if(s.fString) {
        PA_Unichar *allocation = s.fString;
        assert(strings.count(allocation));
        assert(s.fString[s.fLength] == 0);
    }else{
        assert(expected.empty());
    }
    if(!expected.empty())
        assert(memcmp(s.fString, expected.data(), expected.size() * sizeof(PA_Unichar)) == 0);
}
static void clear(PA_Variable *v) {
    ++clears;
    switch(v->fType) {
        case eVK_Unistring: dispose(v->uValue.fString); break;
        case eVK_Object:
        case eVK_Collection: {
            void *p = v->fType == eVK_Object ? v->uValue.fObject : v->uValue.fCollection;
            if(p) {
                assert(refs.count(p) && refs[p] > 0);
                if(--refs[p] == 0) { refs.erase(p); delete static_cast<Ref *>(p); }
            }
            break;
        }
        case eVK_ArrayUnicode: {
            PA_Handle h = v->uValue.fArray.fData;
            assert(handles.count(h));
            auto *s = reinterpret_cast<PA_Unistring *>(*h);
            for(int i = 0; i <= v->uValue.fArray.fNbElements; ++i) dispose(s[i]);
            free(*h); free(h); handles.erase(h);
            break;
        }
        default: assert(v->fType == eVK_Undefined || v->fType == eVK_Boolean ||
                        v->fType == eVK_Real || v->fType == eVK_Longint || v->fType == eVK_Null);
    }
    v->fType = eVK_Undefined;
}
static PA_Variable copy(PA_Variable v) {
    if(v.fType == eVK_Unistring) v.uValue.fString = makeString(v.uValue.fString.fString);
    void *p = nullptr;
    if(v.fType == eVK_Object) p = v.uValue.fObject;
    if(v.fType == eVK_Collection) p = v.uValue.fCollection;
    if(p) ++refs.at(p);
    return v;
}
static void engine(short selector, EngineBlock *eb) {
    switch(selector) {
        case EX_CREATE_UNISTRING:
            eb->fUniString1 = makeString(reinterpret_cast<PA_Unichar *>(eb->fHandle)); break;
        case EX_DISPOSE_UNISTRING: dispose(eb->fUniString1); break;
        case EX_SET_UNISTRING: {
            auto s = makeString(reinterpret_cast<PA_Unichar *>(eb->fHandle));
            dispose(eb->fUniString1); eb->fUniString1 = s; break;
        }
        case EX_VARIABLE_TO_STRING: {
            ++getterStringAccess;
            auto *v = reinterpret_cast<PA_Variable *>(eb->fHandle);
            assert(v->fType == eVK_Unistring);
            eb->fUniString1 = v->uValue.fString;
            checkString(eb->fUniString1, fixture); break;
        }
        case EX_CLEAR_VARIABLE: clear(static_cast<PA_Variable *>(eb->fPtr1)); break;
        case EX_GET_OBJ_VALUE:
            if(failGet) {
                // Poison, not a constructed PA_Variable: failures need not write an owner.
                memset(eb->fPtr2, 0xa5, sizeof(PA_Variable));
                eb->fError = 1;
            }else{
                *static_cast<PA_Variable *>(eb->fPtr2) = copy(property);
            }
            break;
        case EX_SET_OBJ_VALUE:
            clear(&property);
            property = copy(*static_cast<PA_Variable *>(eb->fPtr2)); break;
        case EX_EXECUTE_COMMAND_BY_ID: {
            auto *result = static_cast<PA_Variable *>(eb->fPtr2);
            auto **args = static_cast<PA_Variable **>(eb->fPtr1);
            if(eb->fParam1 == 1231) {
                PA_SetBooleanVariable(result, true);
            }else if(eb->fParam1 == 1217) {
                void *p = args[0]->uValue.fObject;
                assert(args[0]->fType == eVK_Object && refs.count(p));
                if(failCommand) { eb->fError = 1; break; }
                auto s = makeString(fixture.c_str());
                PA_SetStringVariable(result, &s);
            }else{
                assert(!"unexpected command");
            }
            break;
        }
        case EX_HANDLE_MANAGER: {
            PA_Handle h = eb->fHandle;
            switch(eb->fParam1) {
                case 1:
                    if(failHandle) { failHandle = false; eb->fHandle = nullptr; eb->fError = 1; break; }
                    h = static_cast<PA_Handle>(malloc(sizeof(*h)));
                    *h = static_cast<char *>(calloc(1, eb->fParam2 ? eb->fParam2 : 1));
                    handles[h] = eb->fParam2; eb->fHandle = h; break;
                case 2:
                    assert(handles.erase(h) == 1); free(*h); free(h); break;
                case 3:
                    assert(handles.count(h));
                    *h = static_cast<char *>(realloc(*h, eb->fParam2 ? eb->fParam2 : 1));
                    assert(*h); handles[h] = eb->fParam2; break;
                case 4: eb->fParam2 = handles.at(h); break;
                case 5: assert(handles.count(h)); eb->fParam3 = reinterpret_cast<sLONG_PTR>(*h); break;
                case 6: assert(handles.count(h)); break;
                default: assert(!"unexpected handle operation");
            }
            break;
        }
        case EX_RUN_IN_MAIN_PROCESS:
            ++mainCalls;
            reinterpret_cast<PA_RunInMainProcessProcPtr>(eb->fPtr1)(eb->fPtr2); break;
        default: assert(!"unexpected engine entry point");
    }
}
static PA_ObjectRef object() {
    auto *p = new Ref{1}; refs[p] = 1;
    return reinterpret_cast<PA_ObjectRef>(p);
}
static void balance() {
    assert(strings.empty() && handles.empty() && refs.empty());
}
static CUTF8String utf8() {
    const char *expected = "";
    if(!fixture.empty()) {
        switch(fixture[0]) {
            case 't': expected = "text"; break;
            case 0x65e5: expected = "\xe6\x97\xa5\xe6\x9c\xac"; break;
            case 0xd83d: expected = "\xf0\x9f\x98\x83"; break;
            default: assert(!"unexpected fixture");
        }
    }
    return CUTF8String(reinterpret_cast<const uint8_t *>(expected));
}
static void getTests(const std::string &mode) {
    auto obj = object();
    property = PA_CreateVariable(eVK_Undefined);
    auto s = makeString(fixture.c_str());
    PA_SetStringVariable(&property, &s);
    CUTF8String out;
    size_t before = strings.size();
    if(mode == "scalar") {
        assert(ob_get_a(obj, L"key", &out));
        assert(out == utf8());
    }else if(mode == "mismatch") {
        assert(!ob_get_b(obj, L"key"));
        assert(ob_get_n(obj, L"key") == 0);
        assert(ob_get_c(obj, L"key") == nullptr);
        assert(ob_get_o(obj, L"key") == nullptr);
    }else if(mode == "failed-get") {
        failGet = true;
        out = CUTF8String(reinterpret_cast<const uint8_t *>("unchanged"));
        assert(!ob_get_a(obj, L"key", &out));
        assert(!ob_get_b(obj, L"key"));
        assert(ob_get_n(obj, L"key") == 0);
        assert(!ob_get_c(obj, L"key") && !ob_get_o(obj, L"key"));
        assert(out == CUTF8String(reinterpret_cast<const uint8_t *>("unchanged")));
        assert(getterStringAccess == 0);
    }
    assert(strings.size() == before && "getter-result-owner-leak");
    PA_ClearVariable(&property);
    PA_DisposeObject(obj);
    balance();
}
static void handoffs() {
    auto obj = object();
    property = PA_CreateVariable(eVK_Undefined);
    PA_SetObjectVariable(&property, object());
    auto child = ob_get_o(obj, L"key");
    assert(refs.at(child) == 2);
    PA_ClearVariable(&property);
    assert(refs.at(child) == 1);
    PA_DisposeObject(child);
    PA_SetCollectionVariable(&property, reinterpret_cast<PA_CollectionRef>(object()));
    auto collection = ob_get_c(obj, L"key");
    PA_ClearVariable(&property);
    assert(refs.at(collection) == 1);
    PA_DisposeCollection(collection);
    PA_SetObjectVariable(&property, object());
    CUTF8String out;
    assert(ob_get_a(obj, L"key", &out));
    assert(!ob_get_b(obj, L"key"));
    assert(ob_get_n(obj, L"key") == 0);
    assert(!ob_get_c(obj, L"key"));
    void *p = property.uValue.fObject;
    assert(refs.at(p) == 1);
    PA_ClearVariable(&property);
    PA_SetCollectionVariable(&property, reinterpret_cast<PA_CollectionRef>(object()));
    assert(!ob_get_o(obj, L"key"));
    p = property.uValue.fCollection;
    assert(refs.at(p) == 1);
    PA_ClearVariable(&property);
    PA_SetBooleanVariable(&property, true);
    assert(ob_get_b(obj, L"key"));
    PA_SetRealVariable(&property, 4.25);
    assert(ob_get_n(obj, L"key") == 4.25);
    PA_ClearVariable(&property);
    PA_DisposeObject(obj);
    balance();
}
static void stringify(const std::string &mode) {
    auto obj = object();
    CUTF8String out(reinterpret_cast<const uint8_t *>("unchanged"));
    failHandle = mode == "command-handle-failure";
    failCommand = mode == "command-failure";
    ob_stringify(obj, &out);
    if(mode != "stringify") {
        assert(out == CUTF8String(reinterpret_cast<const uint8_t *>("unchanged")));
        assert(getterStringAccess == 0);
    }else{
        assert(out == utf8());
    }
    assert(refs.at(obj) == 1);
    PA_DisposeObject(obj);
    balance();
}
static void arrays() {
    ARRAY_TEXT a;
    a.appendUTF16String(fixture.c_str(), fixture.size());
    a.appendUTF16String(fixture.c_str(), fixture.size());
    PA_Variable arr = PA_CreateVariable(eVK_ArrayUnicode);
    BytePtr params[] = {reinterpret_cast<BytePtr>(&arr)};
    a.toParamAtIndex(params, 1);
    checkString(PA_GetStringInArray(arr, 0), fixture);
    checkString(PA_GetStringInArray(arr, 1), fixture);
    auto first = PA_GetStringInArray(arr, 0);
    auto second = PA_GetStringInArray(arr, 1);
    if(first.fString) assert(first.fString != second.fString);
    ARRAY_TEXT copied;
    copied.fromParamAtIndex(params, 1);
    PA_ClearVariable(&arr);
    arr = PA_CreateVariable(eVK_ArrayUnicode);
    copied.toParamAtIndex(params, 1);
    checkString(PA_GetStringInArray(arr, 1), fixture);
    copied.toParamAtIndex(params, 1); // replacement disposes old independent owners
    PA_ResizeArray(&arr, 0);
    PA_ClearVariable(&arr);
    auto owned = makeString(fixture.c_str());
    auto invalid = PA_CreateVariable(eVK_Undefined);
    PA_SetStringInArray(invalid, 0, &owned);
    arr = PA_CreateVariable(eVK_ArrayUnicode);
    PA_SetStringInArray(arr, -1, &owned);
    PA_SetStringInArray(arr, 1, &owned);
    auto noData = arr; noData.uValue.fArray.fData = nullptr;
    PA_SetStringInArray(noData, 0, &owned);
    PA_SetStringInArray(arr, 0, nullptr);
    checkString(owned, fixture); // all rejected calls retained the caller owner
    PA_DisposeUnistring(&owned);
    PA_ClearVariable(&arr);
    balance();
}
static void scalarContent() {
    auto s = makeString(fixture.c_str());
    PA_Variable callback = PA_CreateVariable(eVK_Undefined);
    PA_SetStringVariable(&callback, &s);
    checkString(callback.uValue.fString, fixture);
    PA_ClearVariable(&callback); // independent synchronous argument, cleared exactly once
    C_TEXT text;
    text.setUTF16String(fixture.c_str(), fixture.size());
    auto dest = makeString(nullptr);
    BytePtr params[] = {reinterpret_cast<BytePtr>(&dest)};
    text.toParamAtIndex(params, 1);
    checkString(dest, fixture);
    text.setUTF16String(nullptr, 0);
    checkString(dest, fixture);
    PA_DisposeUnistring(&dest);
    dest = makeString(nullptr);
    PA_Unistring *result = &dest;
    PluginBlock block = {};
    block.fResult = &result;
    PA_ReturnString(&block, const_cast<PA_Unichar *>(fixture.c_str()));
    checkString(dest, fixture);
    PA_DisposeUnistring(&dest);
    balance();
}
static void setters() {
    auto obj = object();
    property = PA_CreateVariable(eVK_Undefined);
    for(int i = 0; i < 3; ++i) {
        ob_set_a(obj, L"key", &fixture);
        checkString(property.uValue.fString, fixture);
        assert(strings.size() == (fixture.empty() && nullEmpty ? 0 : 1));
        auto value = utf8();
        ob_set_s(obj, "key", reinterpret_cast<const char *>(value.c_str()));
        checkString(property.uValue.fString, fixture);
    }
    PA_ClearVariable(&property);
    PA_DisposeObject(obj);
    balance();
}
static void dispatcher() {
    auditApp = [[AuditApplication alloc] init];
    PackInitBlock init = {};
    init.fCall4Dex = engine;
    FourDPackex(kInitPlugin, &init, nullptr, nullptr);
    PA_long32 enabled = 0;
    sLONG_PTR result = -1;
    void *args[] = {&enabled};
    FourDPackex(1, args, nullptr, nullptr);
    assert([[auditApp.helpMenu title] isEqualToString:@""]);
    FourDPackex(2, nullptr, nullptr, &result);
    assert(result == 0 && mainCalls == 2);
    enabled = 1;
    FourDPackex(1, args, nullptr, nullptr);
    FourDPackex(kDeinitPlugin, nullptr, nullptr, nullptr);
    [auditApp release]; auditApp = nil;
    balance();
}
int main(int argc, char **argv) {
    assert(argc == 4);
    gCall4D = engine;
    const PA_Unichar ascii[] = {'t','e','x','t',0};
    const PA_Unichar bmp[] = {0x65e5,0x672c,0};
    const PA_Unichar supplementary[] = {0xd83d,0xde03,0};
    const PA_Unichar empty[] = {0};
    const PA_Unichar *inputs[] = {ascii, bmp, supplementary, empty};
    fixture = CUTF16String(inputs[atoi(argv[2])]);
    nullEmpty = atoi(argv[3]);
    std::string mode(argv[1]);
    @autoreleasepool {
        if(mode == "scalar" || mode == "mismatch" || mode == "failed-get") getTests(mode);
        else if(mode == "handoffs") handoffs();
        else if(mode == "arrays") arrays();
        else if(mode == "content") scalarContent();
        else if(mode == "setters") setters();
        else if(mode == "dispatcher") dispatcher();
        else stringify(mode);
    }
}
