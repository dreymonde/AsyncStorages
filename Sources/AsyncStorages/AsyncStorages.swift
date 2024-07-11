
internal func shallows_print(_ item: Any) {
    if ShallowsLog.isEnabled {
        print(item)
    }
}

public enum ShallowsLog {
    public static var isEnabled = false
}

